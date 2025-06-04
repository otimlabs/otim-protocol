package crib

import (
	"context"
	"errors"
	"fmt"
	"math/big"
	"sync"

	"github.com/smartcontractkit/chainlink/deployment/ccip/changeset"
	"github.com/smartcontractkit/chainlink/deployment/ccip/changeset/v1_5_1"
	"github.com/smartcontractkit/chainlink/deployment/ccip/changeset/v1_6"

	"golang.org/x/sync/errgroup"

	"github.com/smartcontractkit/chainlink/v2/core/gethwrappers/ccip/generated/v1_5_1/token_pool"

	"github.com/smartcontractkit/chainlink/deployment/ccip/changeset/globals"

	"github.com/smartcontractkit/chainlink-ccip/chainconfig"

	"github.com/smartcontractkit/chainlink/v2/core/capabilities/ccip/types"

	"github.com/ethereum/go-ethereum/common"
	mcmstypes "github.com/smartcontractkit/mcms/types"

	cciptypes "github.com/smartcontractkit/chainlink-ccip/pkg/types/ccipocr3"

	"github.com/smartcontractkit/chainlink/deployment"
	"github.com/smartcontractkit/chainlink/deployment/ccip/changeset/testhelpers"
	commonchangeset "github.com/smartcontractkit/chainlink/deployment/common/changeset"
	commontypes "github.com/smartcontractkit/chainlink/deployment/common/types"
	"github.com/smartcontractkit/chainlink/deployment/environment/devenv"
	"github.com/smartcontractkit/chainlink/v2/core/gethwrappers/ccip/generated/v1_6_0/fee_quoter"
	"github.com/smartcontractkit/chainlink/v2/core/logger"
	"github.com/smartcontractkit/chainlink/v2/core/services/relay"
)

// DeployHomeChainContracts deploys the home chain contracts so that the chainlink nodes can use the CR address in Capabilities.ExternalRegistry
// Afterward, we call DeployHomeChainChangeset changeset with nodeinfo ( the peer id and all)
func DeployHomeChainContracts(ctx context.Context, lggr logger.Logger, envConfig devenv.EnvironmentConfig, homeChainSel uint64, feedChainSel uint64) (deployment.CapabilityRegistryConfig, deployment.AddressBook, error) {
	e, _, err := devenv.NewEnvironment(func() context.Context { return ctx }, lggr, envConfig)
	if err != nil {
		return deployment.CapabilityRegistryConfig{}, nil, err
	}
	if e == nil {
		return deployment.CapabilityRegistryConfig{}, nil, errors.New("environment is nil")
	}

	nodes, err := deployment.NodeInfo(e.NodeIDs, e.Offchain)
	if err != nil {
		return deployment.CapabilityRegistryConfig{}, e.ExistingAddresses, fmt.Errorf("failed to get node info from env: %w", err)
	}
	p2pIds := nodes.NonBootstraps().PeerIDs()
	cfg := make(map[uint64]commontypes.MCMSWithTimelockConfigV2)
	for _, chain := range e.AllChainSelectors() {
		mcmsConfig, err := mcmstypes.NewConfig(1, []common.Address{e.Chains[chain].DeployerKey.From}, []mcmstypes.Config{})
		if err != nil {
			return deployment.CapabilityRegistryConfig{}, e.ExistingAddresses, fmt.Errorf("failed to create mcms config: %w", err)
		}
		cfg[chain] = commontypes.MCMSWithTimelockConfigV2{
			Canceller:        mcmsConfig,
			Bypasser:         mcmsConfig,
			Proposer:         mcmsConfig,
			TimelockMinDelay: big.NewInt(0),
		}
	}
	*e, err = commonchangeset.Apply(nil, *e, nil,
		commonchangeset.Configure(
			deployment.CreateLegacyChangeSet(commonchangeset.DeployMCMSWithTimelockV2),
			cfg,
		),
		commonchangeset.Configure(
			deployment.CreateLegacyChangeSet(v1_6.DeployHomeChainChangeset),
			v1_6.DeployHomeChainConfig{
				HomeChainSel:             homeChainSel,
				RMNStaticConfig:          testhelpers.NewTestRMNStaticConfig(),
				RMNDynamicConfig:         testhelpers.NewTestRMNDynamicConfig(),
				NodeOperators:            testhelpers.NewTestNodeOperator(e.Chains[homeChainSel].DeployerKey.From),
				NodeP2PIDsPerNodeOpAdmin: map[string][][32]byte{"NodeOperator": p2pIds},
			},
		),
	)
	if err != nil {
		return deployment.CapabilityRegistryConfig{}, e.ExistingAddresses, fmt.Errorf("changeset sequence execution failed with error: %w", err)
	}
	state, err := changeset.LoadOnchainState(*e)
	if err != nil {
		return deployment.CapabilityRegistryConfig{}, e.ExistingAddresses, fmt.Errorf("failed to load on chain state: %w", err)
	}
	capRegAddr := state.Chains[homeChainSel].CapabilityRegistry.Address()
	if capRegAddr == common.HexToAddress("0x") {
		return deployment.CapabilityRegistryConfig{}, e.ExistingAddresses, fmt.Errorf("cap Reg address not found: %w", err)
	}
	capRegConfig := deployment.CapabilityRegistryConfig{
		EVMChainID:  homeChainSel,
		Contract:    state.Chains[homeChainSel].CapabilityRegistry.Address(),
		NetworkType: relay.NetworkEVM,
	}
	return capRegConfig, e.ExistingAddresses, nil
}

// DeployCCIPAndAddLanes is the actual ccip setup once the nodes are initialized.
func DeployCCIPAndAddLanes(ctx context.Context, lggr logger.Logger, envConfig devenv.EnvironmentConfig, homeChainSel, feedChainSel uint64, ab deployment.AddressBook) (DeployCCIPOutput, error) {
	e, don, err := devenv.NewEnvironment(func() context.Context { return ctx }, lggr, envConfig)
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to initiate new environment: %w", err)
	}
	e.ExistingAddresses = ab

	// ------ Part 1 -----
	// Setup because we only need to deploy the contracts and distribute job specs
	lggr.Infow("setting up chains...")
	*e, err = setupChains(lggr, e, homeChainSel)
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to apply changesets for setting up chain: %w", err)
	}

	state, err := changeset.LoadOnchainState(*e)
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to load onchain state: %w", err)
	}

	lggr.Infow("setting up lanes...")
	// Add all lanes
	*e, err = setupLanes(e, state)
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to apply changesets for connecting lanes: %w", err)
	}
	// ------ Part 1 -----

	// ----- Part 2 -----
	lggr.Infow("setting up ocr...")
	*e, err = mustOCR(e, homeChainSel, feedChainSel, true)
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to apply changesets for setting up OCR: %w", err)
	}

	// distribute funds to transmitters
	// we need to use the nodeinfo from the envConfig here, because multiAddr is not
	// populated in the environment variable
	lggr.Infow("distributing funds...")
	err = distributeTransmitterFunds(lggr, don.PluginNodes(), *e)
	if err != nil {
		return DeployCCIPOutput{}, err
	}

	addresses, err := e.ExistingAddresses.Addresses()
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to convert address book to address book map: %w", err)
	}
	return DeployCCIPOutput{
		AddressBook: *deployment.NewMemoryAddressBookFromMap(addresses),
		NodeIDs:     e.NodeIDs,
	}, nil
}

// DeployCCIPChains is a group of changesets used from CRIB to set up new chains
// It sets up CCIP contracts on all chains. We expect that MCMS has already been deployed and set up
func DeployCCIPChains(ctx context.Context, lggr logger.Logger, envConfig devenv.EnvironmentConfig, homeChainSel, feedChainSel uint64, ab deployment.AddressBook) (DeployCCIPOutput, error) {
	e, _, err := devenv.NewEnvironment(func() context.Context { return ctx }, lggr, envConfig)
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to initiate new environment: %w", err)
	}
	e.ExistingAddresses = ab

	// Setup because we only need to deploy the contracts and distribute job specs
	lggr.Infow("setting up chains...")
	*e, err = setupChains(lggr, e, homeChainSel)
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to apply changesets for setting up chain: %w", err)
	}
	addresses, err := e.ExistingAddresses.Addresses()
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to get convert address book to address book map: %w", err)
	}
	return DeployCCIPOutput{
		AddressBook: *deployment.NewMemoryAddressBookFromMap(addresses),
		NodeIDs:     e.NodeIDs,
	}, nil
}

// ConnectCCIPLanes is a group of changesets used from CRIB to set up new lanes
// It creates a fully connected mesh where all chains are connected to all chains
func ConnectCCIPLanes(ctx context.Context, lggr logger.Logger, envConfig devenv.EnvironmentConfig, homeChainSel, feedChainSel uint64, ab deployment.AddressBook) (DeployCCIPOutput, error) {
	e, _, err := devenv.NewEnvironment(func() context.Context { return ctx }, lggr, envConfig)
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to initiate new environment: %w", err)
	}
	e.ExistingAddresses = ab

	state, err := changeset.LoadOnchainState(*e)
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to load onchain state: %w", err)
	}

	lggr.Infow("setting up lanes...")
	// Add all lanes
	*e, err = setupLanes(e, state)
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to apply changesets for connecting lanes: %w", err)
	}

	addresses, err := e.ExistingAddresses.Addresses()
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to get convert address book to address book map: %w", err)
	}
	return DeployCCIPOutput{
		AddressBook: *deployment.NewMemoryAddressBookFromMap(addresses),
		NodeIDs:     e.NodeIDs,
	}, nil
}

// ConfigureCCIPOCR is a group of changesets used from CRIB to redeploy the chainlink don on an existing setup
func ConfigureCCIPOCR(ctx context.Context, lggr logger.Logger, envConfig devenv.EnvironmentConfig, homeChainSel, feedChainSel uint64, ab deployment.AddressBook) (DeployCCIPOutput, error) {
	e, _, err := devenv.NewEnvironment(func() context.Context { return ctx }, lggr, envConfig)
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to initiate new environment: %w", err)
	}
	e.ExistingAddresses = ab

	lggr.Infow("resetting ocr...")
	*e, err = mustOCR(e, homeChainSel, feedChainSel, false)
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to apply changesets for setting up OCR: %w", err)
	}

	addresses, err := e.ExistingAddresses.Addresses()
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to get convert address book to address book map: %w", err)
	}
	return DeployCCIPOutput{
		AddressBook: *deployment.NewMemoryAddressBookFromMap(addresses),
		NodeIDs:     e.NodeIDs,
	}, nil
}

// FundCCIPTransmitters is used from CRIB to provide funds to the node transmitters
// This function sends funds from the deployer key to the chainlink node transmitters
func FundCCIPTransmitters(ctx context.Context, lggr logger.Logger, envConfig devenv.EnvironmentConfig, ab deployment.AddressBook) (DeployCCIPOutput, error) {
	e, don, err := devenv.NewEnvironment(func() context.Context { return ctx }, lggr, envConfig)
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to initiate new environment: %w", err)
	}
	e.ExistingAddresses = ab

	// distribute funds to transmitters
	// we need to use the nodeinfo from the envConfig here, because multiAddr is not
	// populated in the environment variable
	lggr.Infow("distributing funds...")
	err = distributeTransmitterFunds(lggr, don.PluginNodes(), *e)
	if err != nil {
		return DeployCCIPOutput{}, err
	}

	addresses, err := e.ExistingAddresses.Addresses()
	if err != nil {
		return DeployCCIPOutput{}, fmt.Errorf("failed to get convert address book to address book map: %w", err)
	}
	return DeployCCIPOutput{
		AddressBook: *deployment.NewMemoryAddressBookFromMap(addresses),
		NodeIDs:     e.NodeIDs,
	}, nil
}

func setupChains(lggr logger.Logger, e *deployment.Environment, homeChainSel uint64) (deployment.Environment, error) {
	chainSelectors := e.AllChainSelectors()
	chainConfigs := make(map[uint64]v1_6.ChainConfig)
	nodeInfo, err := deployment.NodeInfo(e.NodeIDs, e.Offchain)
	if err != nil {
		return *e, fmt.Errorf("failed to get node info from env: %w", err)
	}
	prereqCfgs := make([]changeset.DeployPrerequisiteConfigPerChain, 0)
	contractParams := make(map[uint64]v1_6.ChainContractParams)

	for _, chain := range chainSelectors {
		prereqCfgs = append(prereqCfgs, changeset.DeployPrerequisiteConfigPerChain{
			ChainSelector: chain,
		})
		chainConfigs[chain] = v1_6.ChainConfig{
			Readers: nodeInfo.NonBootstraps().PeerIDs(),
			// Number of nodes is 3f+1
			//nolint:gosec // this should always be less than max uint8
			FChain: uint8(len(nodeInfo.NonBootstraps().PeerIDs()) / 3),
			EncodableChainConfig: chainconfig.ChainConfig{
				GasPriceDeviationPPB:    cciptypes.BigInt{Int: big.NewInt(1000)},
				DAGasPriceDeviationPPB:  cciptypes.BigInt{Int: big.NewInt(1_000_000)},
				OptimisticConfirmations: 1,
			},
		}
		contractParams[chain] = v1_6.ChainContractParams{
			FeeQuoterParams: v1_6.DefaultFeeQuoterParams(),
			OffRampParams:   v1_6.DefaultOffRampParams(),
		}
	}
	env, err := commonchangeset.Apply(nil, *e, nil,
		commonchangeset.Configure(
			deployment.CreateLegacyChangeSet(v1_6.UpdateChainConfigChangeset),
			v1_6.UpdateChainConfigConfig{
				HomeChainSelector: homeChainSel,
				RemoteChainAdds:   chainConfigs,
			},
		),
		commonchangeset.Configure(
			deployment.CreateLegacyChangeSet(commonchangeset.DeployLinkToken),
			chainSelectors,
		),
		commonchangeset.Configure(
			deployment.CreateLegacyChangeSet(changeset.DeployPrerequisitesChangeset),
			changeset.DeployPrerequisiteConfig{
				Configs: prereqCfgs,
			},
		),
		commonchangeset.Configure(
			deployment.CreateLegacyChangeSet(v1_6.DeployChainContractsChangeset),
			v1_6.DeployChainContractsConfig{
				HomeChainSelector:      homeChainSel,
				ContractParamsPerChain: contractParams,
			},
		),
		commonchangeset.Configure(
			deployment.CreateLegacyChangeSet(v1_6.SetRMNRemoteOnRMNProxyChangeset),
			v1_6.SetRMNRemoteOnRMNProxyConfig{
				ChainSelectors: chainSelectors,
			},
		),
		commonchangeset.Configure(
			deployment.CreateLegacyChangeSet(v1_6.CCIPCapabilityJobspecChangeset),
			nil, // ChangeSet does not use a config.
		),
	)
	if err != nil {
		return *e, fmt.Errorf("failed to apply changesets: %w", err)
	}
	lggr.Infow("setup Link pools")
	return setupLinkPools(&env)
}

func setupLinkPools(e *deployment.Environment) (deployment.Environment, error) {
	state, err := changeset.LoadOnchainState(*e)
	if err != nil {
		return *e, fmt.Errorf("failed to load onchain state: %w", err)
	}
	chainSelectors := e.AllChainSelectors()
	poolInput := make(map[uint64]v1_5_1.DeployTokenPoolInput)
	pools := make(map[uint64]map[changeset.TokenSymbol]changeset.TokenPoolInfo)
	for _, chain := range chainSelectors {
		poolInput[chain] = v1_5_1.DeployTokenPoolInput{
			Type:               changeset.BurnMintTokenPool,
			LocalTokenDecimals: 18,
			AllowList:          []common.Address{},
			TokenAddress:       state.Chains[chain].LinkToken.Address(),
		}
		pools[chain] = map[changeset.TokenSymbol]changeset.TokenPoolInfo{
			changeset.LinkSymbol: {
				Type:          changeset.BurnMintTokenPool,
				Version:       deployment.Version1_5_1,
				ExternalAdmin: e.Chains[chain].DeployerKey.From,
			},
		}
	}
	env, err := commonchangeset.Apply(nil, *e, nil,
		commonchangeset.Configure(
			deployment.CreateLegacyChangeSet(v1_5_1.DeployTokenPoolContractsChangeset),
			v1_5_1.DeployTokenPoolContractsConfig{
				TokenSymbol: changeset.LinkSymbol,
				NewPools:    poolInput,
			},
		),
		commonchangeset.Configure(
			deployment.CreateLegacyChangeSet(v1_5_1.ProposeAdminRoleChangeset),
			changeset.TokenAdminRegistryChangesetConfig{
				Pools: pools,
			},
		),
		commonchangeset.Configure(
			deployment.CreateLegacyChangeSet(v1_5_1.AcceptAdminRoleChangeset),
			changeset.TokenAdminRegistryChangesetConfig{
				Pools: pools,
			},
		),
		commonchangeset.Configure(
			deployment.CreateLegacyChangeSet(v1_5_1.SetPoolChangeset),
			changeset.TokenAdminRegistryChangesetConfig{
				Pools: pools,
			},
		),
	)

	if err != nil {
		return *e, fmt.Errorf("failed to apply changesets: %w", err)
	}

	state, err = changeset.LoadOnchainState(env)
	if err != nil {
		return *e, fmt.Errorf("failed to load onchain state: %w", err)
	}

	for _, chain := range chainSelectors {
		linkPool := state.Chains[chain].BurnMintTokenPools[changeset.LinkSymbol][deployment.Version1_5_1]
		linkToken := state.Chains[chain].LinkToken
		tx, err := linkToken.GrantMintAndBurnRoles(e.Chains[chain].DeployerKey, linkPool.Address())
		_, err = deployment.ConfirmIfNoError(e.Chains[chain], tx, err)
		if err != nil {
			return *e, fmt.Errorf("failed to grant mint and burn roles for link pool: %w", err)
		}
	}
	return env, err
}

func setupLanes(e *deployment.Environment, state changeset.CCIPOnChainState) (deployment.Environment, error) {
	eg := errgroup.Group{}
	poolUpdates := make(map[uint64]v1_5_1.TokenPoolConfig)
	rateLimitPerChain := make(v1_5_1.RateLimiterPerChain)
	mu := sync.Mutex{}
	for src := range e.Chains {
		src := src
		eg.Go(func() error {
			onRampUpdatesByChain := make(map[uint64]map[uint64]v1_6.OnRampDestinationUpdate)
			pricesByChain := make(map[uint64]v1_6.FeeQuoterPriceUpdatePerSource)
			feeQuoterDestsUpdatesByChain := make(map[uint64]map[uint64]fee_quoter.FeeQuoterDestChainConfig)
			updateOffRampSources := make(map[uint64]map[uint64]v1_6.OffRampSourceUpdate)
			updateRouterChanges := make(map[uint64]v1_6.RouterUpdates)
			onRampUpdatesByChain[src] = make(map[uint64]v1_6.OnRampDestinationUpdate)
			pricesByChain[src] = v1_6.FeeQuoterPriceUpdatePerSource{
				TokenPrices: map[common.Address]*big.Int{
					state.Chains[src].LinkToken.Address(): testhelpers.DefaultLinkPrice,
					state.Chains[src].Weth9.Address():     testhelpers.DefaultWethPrice,
				},
				GasPrices: make(map[uint64]*big.Int),
			}
			feeQuoterDestsUpdatesByChain[src] = make(map[uint64]fee_quoter.FeeQuoterDestChainConfig)
			updateOffRampSources[src] = make(map[uint64]v1_6.OffRampSourceUpdate)
			updateRouterChanges[src] = v1_6.RouterUpdates{
				OffRampUpdates: make(map[uint64]bool),
				OnRampUpdates:  make(map[uint64]bool),
			}

			for dst := range e.Chains {
				if src != dst {
					onRampUpdatesByChain[src][dst] = v1_6.OnRampDestinationUpdate{
						IsEnabled:        true,
						AllowListEnabled: false,
					}
					pricesByChain[src].GasPrices[dst] = testhelpers.DefaultGasPrice
					feeQuoterDestsUpdatesByChain[src][dst] = v1_6.DefaultFeeQuoterDestChainConfig(true)

					updateOffRampSources[src][dst] = v1_6.OffRampSourceUpdate{
						IsEnabled:                 true,
						IsRMNVerificationDisabled: true,
					}

					updateRouterChanges[src].OffRampUpdates[dst] = true
					updateRouterChanges[src].OnRampUpdates[dst] = true
					mu.Lock()
					rateLimitPerChain[dst] = v1_5_1.RateLimiterConfig{
						Inbound: token_pool.RateLimiterConfig{
							IsEnabled: false,
							Capacity:  big.NewInt(0),
							Rate:      big.NewInt(0),
						},
						Outbound: token_pool.RateLimiterConfig{
							IsEnabled: false,
							Capacity:  big.NewInt(0),
							Rate:      big.NewInt(0),
						},
					}
					mu.Unlock()
				}
			}
			mu.Lock()
			poolUpdates[src] = v1_5_1.TokenPoolConfig{
				Type:         changeset.BurnMintTokenPool,
				Version:      deployment.Version1_5_1,
				ChainUpdates: rateLimitPerChain,
			}
			mu.Unlock()

			_, err := commonchangeset.Apply(nil, *e, nil,
				commonchangeset.Configure(
					deployment.CreateLegacyChangeSet(v1_6.UpdateOnRampsDestsChangeset),
					v1_6.UpdateOnRampDestsConfig{
						UpdatesByChain: onRampUpdatesByChain,
					},
				),
				commonchangeset.Configure(
					deployment.CreateLegacyChangeSet(v1_6.UpdateFeeQuoterPricesChangeset),
					v1_6.UpdateFeeQuoterPricesConfig{
						PricesByChain: pricesByChain,
					},
				),
				commonchangeset.Configure(
					deployment.CreateLegacyChangeSet(v1_6.UpdateFeeQuoterDestsChangeset),
					v1_6.UpdateFeeQuoterDestsConfig{
						UpdatesByChain: feeQuoterDestsUpdatesByChain,
					},
				),
				commonchangeset.Configure(
					deployment.CreateLegacyChangeSet(v1_6.UpdateOffRampSourcesChangeset),
					v1_6.UpdateOffRampSourcesConfig{
						UpdatesByChain: updateOffRampSources,
					},
				),
				commonchangeset.Configure(
					deployment.CreateLegacyChangeSet(v1_6.UpdateRouterRampsChangeset),
					v1_6.UpdateRouterRampsConfig{
						UpdatesByChain: updateRouterChanges,
					},
				),
			)
			return err
		})
	}

	err := eg.Wait()
	if err != nil {
		return *e, err
	}

	_, err = commonchangeset.Apply(nil, *e, nil, commonchangeset.Configure(
		deployment.CreateLegacyChangeSet(v1_5_1.ConfigureTokenPoolContractsChangeset),
		v1_5_1.ConfigureTokenPoolContractsConfig{
			TokenSymbol: changeset.LinkSymbol,
			PoolUpdates: poolUpdates,
		},
	))

	return *e, err
}

func mustOCR(e *deployment.Environment, homeChainSel uint64, feedChainSel uint64, newDons bool) (deployment.Environment, error) {
	chainSelectors := e.AllChainSelectors()
	var commitOCRConfigPerSelector = make(map[uint64]v1_6.CCIPOCRParams)
	var execOCRConfigPerSelector = make(map[uint64]v1_6.CCIPOCRParams)
	// Should be configured in the future based on the load test scenario
	// chainType := v1_6.Default

	// TODO Passing SimulationTest to reduce number of changes in the CRIB (load test setup)
	// @Austin please flip it back to Default once we reach a stable state
	chainType := v1_6.SimulationTest
	for selector := range e.Chains {
		commitOCRConfigPerSelector[selector] = v1_6.DeriveOCRParamsForCommit(chainType, feedChainSel, nil, nil)
		execOCRConfigPerSelector[selector] = v1_6.DeriveOCRParamsForExec(chainType, nil, nil)
	}

	var commitChangeset commonchangeset.ConfiguredChangeSet
	if newDons {
		commitChangeset = commonchangeset.Configure(
			// Add the DONs and candidate commit OCR instances for the chain
			deployment.CreateLegacyChangeSet(v1_6.AddDonAndSetCandidateChangeset),
			v1_6.AddDonAndSetCandidateChangesetConfig{
				SetCandidateConfigBase: v1_6.SetCandidateConfigBase{
					HomeChainSelector: homeChainSel,
					FeedChainSelector: feedChainSel,
				},
				PluginInfo: v1_6.SetCandidatePluginInfo{
					OCRConfigPerRemoteChainSelector: commitOCRConfigPerSelector,
					PluginType:                      types.PluginTypeCCIPCommit,
				},
			},
		)
	} else {
		commitChangeset = commonchangeset.Configure(
			// Update commit OCR instances for existing chains
			deployment.CreateLegacyChangeSet(v1_6.SetCandidateChangeset),
			v1_6.SetCandidateChangesetConfig{
				SetCandidateConfigBase: v1_6.SetCandidateConfigBase{
					HomeChainSelector: homeChainSel,
					FeedChainSelector: feedChainSel,
				},
				PluginInfo: []v1_6.SetCandidatePluginInfo{
					{
						OCRConfigPerRemoteChainSelector: commitOCRConfigPerSelector,
						PluginType:                      types.PluginTypeCCIPCommit,
					},
				},
			},
		)
	}

	return commonchangeset.Apply(nil, *e, nil,
		commitChangeset,
		commonchangeset.Configure(
			// Add the exec OCR instances for the new chains
			deployment.CreateLegacyChangeSet(v1_6.SetCandidateChangeset),
			v1_6.SetCandidateChangesetConfig{
				SetCandidateConfigBase: v1_6.SetCandidateConfigBase{
					HomeChainSelector: homeChainSel,
					FeedChainSelector: feedChainSel,
				},
				PluginInfo: []v1_6.SetCandidatePluginInfo{
					{
						OCRConfigPerRemoteChainSelector: execOCRConfigPerSelector,
						PluginType:                      types.PluginTypeCCIPExec,
					},
				},
			},
		),
		commonchangeset.Configure(
			// Promote everything
			deployment.CreateLegacyChangeSet(v1_6.PromoteCandidateChangeset),
			v1_6.PromoteCandidateChangesetConfig{
				HomeChainSelector: homeChainSel,
				PluginInfo: []v1_6.PromoteCandidatePluginInfo{
					{
						RemoteChainSelectors: chainSelectors,
						PluginType:           types.PluginTypeCCIPCommit,
					},
					{
						RemoteChainSelectors: chainSelectors,
						PluginType:           types.PluginTypeCCIPExec,
					},
				},
			},
		),
		commonchangeset.Configure(
			// Enable the OCR config on the remote chains
			deployment.CreateLegacyChangeSet(v1_6.SetOCR3OffRampChangeset),
			v1_6.SetOCR3OffRampConfig{
				HomeChainSel:       homeChainSel,
				RemoteChainSels:    chainSelectors,
				CCIPHomeConfigType: globals.ConfigTypeActive,
			},
		),
	)
}
