// Code generated by mockery v2.53.0. DO NOT EDIT.

package mocks

import (
	context "context"
	big "math/big"

	common "github.com/ethereum/go-ethereum/common"

	ethkey "github.com/smartcontractkit/chainlink/v2/core/services/keystore/keys/ethkey"

	mock "github.com/stretchr/testify/mock"
)

// KeyStoreInterface is an autogenerated mock type for the KeyStoreInterface type
type KeyStoreInterface struct {
	mock.Mock
}

type KeyStoreInterface_Expecter struct {
	mock *mock.Mock
}

func (_m *KeyStoreInterface) EXPECT() *KeyStoreInterface_Expecter {
	return &KeyStoreInterface_Expecter{mock: &_m.Mock}
}

// EnabledKeysForChain provides a mock function with given fields: ctx, chainID
func (_m *KeyStoreInterface) EnabledKeysForChain(ctx context.Context, chainID *big.Int) ([]ethkey.KeyV2, error) {
	ret := _m.Called(ctx, chainID)

	if len(ret) == 0 {
		panic("no return value specified for EnabledKeysForChain")
	}

	var r0 []ethkey.KeyV2
	var r1 error
	if rf, ok := ret.Get(0).(func(context.Context, *big.Int) ([]ethkey.KeyV2, error)); ok {
		return rf(ctx, chainID)
	}
	if rf, ok := ret.Get(0).(func(context.Context, *big.Int) []ethkey.KeyV2); ok {
		r0 = rf(ctx, chainID)
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).([]ethkey.KeyV2)
		}
	}

	if rf, ok := ret.Get(1).(func(context.Context, *big.Int) error); ok {
		r1 = rf(ctx, chainID)
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// KeyStoreInterface_EnabledKeysForChain_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'EnabledKeysForChain'
type KeyStoreInterface_EnabledKeysForChain_Call struct {
	*mock.Call
}

// EnabledKeysForChain is a helper method to define mock.On call
//   - ctx context.Context
//   - chainID *big.Int
func (_e *KeyStoreInterface_Expecter) EnabledKeysForChain(ctx interface{}, chainID interface{}) *KeyStoreInterface_EnabledKeysForChain_Call {
	return &KeyStoreInterface_EnabledKeysForChain_Call{Call: _e.mock.On("EnabledKeysForChain", ctx, chainID)}
}

func (_c *KeyStoreInterface_EnabledKeysForChain_Call) Run(run func(ctx context.Context, chainID *big.Int)) *KeyStoreInterface_EnabledKeysForChain_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(context.Context), args[1].(*big.Int))
	})
	return _c
}

func (_c *KeyStoreInterface_EnabledKeysForChain_Call) Return(_a0 []ethkey.KeyV2, _a1 error) *KeyStoreInterface_EnabledKeysForChain_Call {
	_c.Call.Return(_a0, _a1)
	return _c
}

func (_c *KeyStoreInterface_EnabledKeysForChain_Call) RunAndReturn(run func(context.Context, *big.Int) ([]ethkey.KeyV2, error)) *KeyStoreInterface_EnabledKeysForChain_Call {
	_c.Call.Return(run)
	return _c
}

// GetRoundRobinAddress provides a mock function with given fields: ctx, chainID, addrs
func (_m *KeyStoreInterface) GetRoundRobinAddress(ctx context.Context, chainID *big.Int, addrs ...common.Address) (common.Address, error) {
	_va := make([]interface{}, len(addrs))
	for _i := range addrs {
		_va[_i] = addrs[_i]
	}
	var _ca []interface{}
	_ca = append(_ca, ctx, chainID)
	_ca = append(_ca, _va...)
	ret := _m.Called(_ca...)

	if len(ret) == 0 {
		panic("no return value specified for GetRoundRobinAddress")
	}

	var r0 common.Address
	var r1 error
	if rf, ok := ret.Get(0).(func(context.Context, *big.Int, ...common.Address) (common.Address, error)); ok {
		return rf(ctx, chainID, addrs...)
	}
	if rf, ok := ret.Get(0).(func(context.Context, *big.Int, ...common.Address) common.Address); ok {
		r0 = rf(ctx, chainID, addrs...)
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(common.Address)
		}
	}

	if rf, ok := ret.Get(1).(func(context.Context, *big.Int, ...common.Address) error); ok {
		r1 = rf(ctx, chainID, addrs...)
	} else {
		r1 = ret.Error(1)
	}

	return r0, r1
}

// KeyStoreInterface_GetRoundRobinAddress_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'GetRoundRobinAddress'
type KeyStoreInterface_GetRoundRobinAddress_Call struct {
	*mock.Call
}

// GetRoundRobinAddress is a helper method to define mock.On call
//   - ctx context.Context
//   - chainID *big.Int
//   - addrs ...common.Address
func (_e *KeyStoreInterface_Expecter) GetRoundRobinAddress(ctx interface{}, chainID interface{}, addrs ...interface{}) *KeyStoreInterface_GetRoundRobinAddress_Call {
	return &KeyStoreInterface_GetRoundRobinAddress_Call{Call: _e.mock.On("GetRoundRobinAddress",
		append([]interface{}{ctx, chainID}, addrs...)...)}
}

func (_c *KeyStoreInterface_GetRoundRobinAddress_Call) Run(run func(ctx context.Context, chainID *big.Int, addrs ...common.Address)) *KeyStoreInterface_GetRoundRobinAddress_Call {
	_c.Call.Run(func(args mock.Arguments) {
		variadicArgs := make([]common.Address, len(args)-2)
		for i, a := range args[2:] {
			if a != nil {
				variadicArgs[i] = a.(common.Address)
			}
		}
		run(args[0].(context.Context), args[1].(*big.Int), variadicArgs...)
	})
	return _c
}

func (_c *KeyStoreInterface_GetRoundRobinAddress_Call) Return(_a0 common.Address, _a1 error) *KeyStoreInterface_GetRoundRobinAddress_Call {
	_c.Call.Return(_a0, _a1)
	return _c
}

func (_c *KeyStoreInterface_GetRoundRobinAddress_Call) RunAndReturn(run func(context.Context, *big.Int, ...common.Address) (common.Address, error)) *KeyStoreInterface_GetRoundRobinAddress_Call {
	_c.Call.Return(run)
	return _c
}

// NewKeyStoreInterface creates a new instance of KeyStoreInterface. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
// The first argument is typically a *testing.T value.
func NewKeyStoreInterface(t interface {
	mock.TestingT
	Cleanup(func())
}) *KeyStoreInterface {
	mock := &KeyStoreInterface{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}
