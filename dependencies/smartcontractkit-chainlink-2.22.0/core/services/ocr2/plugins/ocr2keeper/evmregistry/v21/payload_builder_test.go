package evm

import (
	"context"
	"math/big"
	"testing"

	"github.com/pkg/errors"
	"github.com/stretchr/testify/assert"

	"github.com/smartcontractkit/chainlink-automation/pkg/v3/types"
	"github.com/smartcontractkit/chainlink-common/pkg/types/automation"

	"github.com/smartcontractkit/chainlink/v2/core/internal/testutils"
	"github.com/smartcontractkit/chainlink/v2/core/logger"
	"github.com/smartcontractkit/chainlink/v2/core/services/ocr2/plugins/ocr2keeper/evmregistry/v21/core"
	"github.com/smartcontractkit/chainlink/v2/core/services/ocr2/plugins/ocr2keeper/evmregistry/v21/logprovider"
)

func TestNewPayloadBuilder(t *testing.T) {
	for _, tc := range []struct {
		name         string
		activeList   ActiveUpkeepList
		recoverer    logprovider.LogRecoverer
		proposals    []automation.CoordinatedBlockProposal
		wantPayloads []automation.UpkeepPayload
	}{
		{
			name: "for log trigger upkeeps, new payloads are created",
			activeList: &mockActiveUpkeepList{
				IsActiveFn: func(id *big.Int) bool {
					return true
				},
			},
			proposals: []automation.CoordinatedBlockProposal{
				{
					UpkeepID: core.GenUpkeepID(types.LogTrigger, "abc"),
					WorkID:   "workID1",
					Trigger: automation.Trigger{
						BlockNumber: 1,
						BlockHash:   [32]byte{1},
					},
				},
				{
					UpkeepID: core.GenUpkeepID(types.LogTrigger, "def"),
					WorkID:   "workID2",
					Trigger: automation.Trigger{
						BlockNumber: 2,
						BlockHash:   [32]byte{2},
					},
				},
			},
			recoverer: &mockLogRecoverer{
				GetProposalDataFn: func(ctx context.Context, proposal automation.CoordinatedBlockProposal) ([]byte, error) {
					return []byte{1, 2, 3}, nil
				},
			},
			wantPayloads: []automation.UpkeepPayload{
				{
					UpkeepID: core.GenUpkeepID(types.LogTrigger, "abc"),
					WorkID:   "714f83255c5b562823725748c4a75777c9b78ea8c5ba72ea819926a1fecd389e",
					Trigger: automation.Trigger{
						BlockNumber: 1,
						BlockHash:   [32]byte{1},
					},
					CheckData: []byte{1, 2, 3},
				},
				{
					UpkeepID: core.GenUpkeepID(types.LogTrigger, "def"),
					WorkID:   "3956daa0378d6a761fe972ee00fe98338f17fb6b7865c1d49a8a416cd85977b8",
					Trigger: automation.Trigger{
						BlockNumber: 2,
						BlockHash:   [32]byte{2},
					},
					CheckData: []byte{1, 2, 3},
				},
			},
		},
		{
			name: "for an inactive log trigger upkeep, an empty payload is added to the list of payloads",
			activeList: &mockActiveUpkeepList{
				IsActiveFn: func(id *big.Int) bool {
					return core.GenUpkeepID(types.LogTrigger, "ghi").BigInt().Cmp(id) != 0
				},
			},
			proposals: []automation.CoordinatedBlockProposal{
				{
					UpkeepID: core.GenUpkeepID(types.LogTrigger, "abc"),
					WorkID:   "workID1",
					Trigger: automation.Trigger{
						BlockNumber: 1,
						BlockHash:   [32]byte{1},
					},
				},
				{
					UpkeepID: core.GenUpkeepID(types.LogTrigger, "def"),
					WorkID:   "workID2",
					Trigger: automation.Trigger{
						BlockNumber: 2,
						BlockHash:   [32]byte{2},
					},
				},
				{
					UpkeepID: core.GenUpkeepID(types.LogTrigger, "ghi"),
					WorkID:   "workID3",
					Trigger: automation.Trigger{
						BlockNumber: 3,
						BlockHash:   [32]byte{3},
					},
				},
			},
			recoverer: &mockLogRecoverer{
				GetProposalDataFn: func(ctx context.Context, proposal automation.CoordinatedBlockProposal) ([]byte, error) {
					return []byte{1, 2, 3}, nil
				},
			},
			wantPayloads: []automation.UpkeepPayload{
				{
					UpkeepID: core.GenUpkeepID(types.LogTrigger, "abc"),
					WorkID:   "714f83255c5b562823725748c4a75777c9b78ea8c5ba72ea819926a1fecd389e",
					Trigger: automation.Trigger{
						BlockNumber: 1,
						BlockHash:   [32]byte{1},
					},
					CheckData: []byte{1, 2, 3},
				},
				{
					UpkeepID: core.GenUpkeepID(types.LogTrigger, "def"),
					WorkID:   "3956daa0378d6a761fe972ee00fe98338f17fb6b7865c1d49a8a416cd85977b8",
					Trigger: automation.Trigger{
						BlockNumber: 2,
						BlockHash:   [32]byte{2},
					},
					CheckData: []byte{1, 2, 3},
				},
				{},
			},
		},
		{
			name: "when the recoverer errors, an empty payload is created but not added to the list of payloads",
			activeList: &mockActiveUpkeepList{
				IsActiveFn: func(id *big.Int) bool {
					return true
				},
			},
			proposals: []automation.CoordinatedBlockProposal{
				{
					UpkeepID: core.GenUpkeepID(types.LogTrigger, "abc"),
					WorkID:   "workID1",
					Trigger: automation.Trigger{
						BlockNumber: 1,
						BlockHash:   [32]byte{1},
					},
				},
			},
			recoverer: &mockLogRecoverer{
				GetProposalDataFn: func(ctx context.Context, proposal automation.CoordinatedBlockProposal) ([]byte, error) {
					return nil, errors.New("recoverer boom")
				},
			},
			wantPayloads: []automation.UpkeepPayload{
				{},
			},
		},
		{
			name: "for a conditional upkeep, a new payload with empty check data is added to the list of payloads",
			activeList: &mockActiveUpkeepList{
				IsActiveFn: func(id *big.Int) bool {
					return true
				},
			},
			proposals: []automation.CoordinatedBlockProposal{
				{
					UpkeepID: core.GenUpkeepID(types.ConditionTrigger, "def"),
					WorkID:   "workID1",
					Trigger: automation.Trigger{
						BlockNumber: 1,
						BlockHash:   [32]byte{1},
					},
				},
			},
			wantPayloads: []automation.UpkeepPayload{
				{
					UpkeepID: core.GenUpkeepID(types.ConditionTrigger, "def"),
					WorkID:   "58f2f231792448679a75bac6efc2af4ba731901f0cb93a44a366525751cbabfb",
					Trigger: automation.Trigger{
						BlockNumber: 1,
						BlockHash:   [32]byte{1},
					},
				},
			},
		},
	} {
		t.Run(tc.name, func(t *testing.T) {
			lggr, _ := logger.NewLogger()
			builder := NewPayloadBuilder(tc.activeList, tc.recoverer, lggr)
			payloads, err := builder.BuildPayloads(testutils.Context(t), tc.proposals...)
			assert.NoError(t, err)
			assert.Equal(t, tc.wantPayloads, payloads)
		})
	}
}

type mockLogRecoverer struct {
	logprovider.LogRecoverer
	GetProposalDataFn func(context.Context, automation.CoordinatedBlockProposal) ([]byte, error)
}

func (r *mockLogRecoverer) GetProposalData(ctx context.Context, p automation.CoordinatedBlockProposal) ([]byte, error) {
	return r.GetProposalDataFn(ctx, p)
}
