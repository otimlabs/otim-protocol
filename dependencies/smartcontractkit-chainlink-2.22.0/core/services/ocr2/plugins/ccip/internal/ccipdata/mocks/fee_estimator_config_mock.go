// Code generated by mockery v2.53.0. DO NOT EDIT.

package mocks

import (
	big "math/big"

	context "context"

	mock "github.com/stretchr/testify/mock"
)

// FeeEstimatorConfigReader is an autogenerated mock type for the FeeEstimatorConfigReader type
type FeeEstimatorConfigReader struct {
	mock.Mock
}

type FeeEstimatorConfigReader_Expecter struct {
	mock *mock.Mock
}

func (_m *FeeEstimatorConfigReader) EXPECT() *FeeEstimatorConfigReader_Expecter {
	return &FeeEstimatorConfigReader_Expecter{mock: &_m.Mock}
}

// GetDataAvailabilityConfig provides a mock function with given fields: ctx
func (_m *FeeEstimatorConfigReader) GetDataAvailabilityConfig(ctx context.Context) (int64, int64, int64, error) {
	ret := _m.Called(ctx)

	if len(ret) == 0 {
		panic("no return value specified for GetDataAvailabilityConfig")
	}

	var r0 int64
	var r1 int64
	var r2 int64
	var r3 error
	if rf, ok := ret.Get(0).(func(context.Context) (int64, int64, int64, error)); ok {
		return rf(ctx)
	}
	if rf, ok := ret.Get(0).(func(context.Context) int64); ok {
		r0 = rf(ctx)
	} else {
		r0 = ret.Get(0).(int64)
	}

	if rf, ok := ret.Get(1).(func(context.Context) int64); ok {
		r1 = rf(ctx)
	} else {
		r1 = ret.Get(1).(int64)
	}

	if rf, ok := ret.Get(2).(func(context.Context) int64); ok {
		r2 = rf(ctx)
	} else {
		r2 = ret.Get(2).(int64)
	}

	if rf, ok := ret.Get(3).(func(context.Context) error); ok {
		r3 = rf(ctx)
	} else {
		r3 = ret.Error(3)
	}

	return r0, r1, r2, r3
}

// FeeEstimatorConfigReader_GetDataAvailabilityConfig_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'GetDataAvailabilityConfig'
type FeeEstimatorConfigReader_GetDataAvailabilityConfig_Call struct {
	*mock.Call
}

// GetDataAvailabilityConfig is a helper method to define mock.On call
//   - ctx context.Context
func (_e *FeeEstimatorConfigReader_Expecter) GetDataAvailabilityConfig(ctx interface{}) *FeeEstimatorConfigReader_GetDataAvailabilityConfig_Call {
	return &FeeEstimatorConfigReader_GetDataAvailabilityConfig_Call{Call: _e.mock.On("GetDataAvailabilityConfig", ctx)}
}

func (_c *FeeEstimatorConfigReader_GetDataAvailabilityConfig_Call) Run(run func(ctx context.Context)) *FeeEstimatorConfigReader_GetDataAvailabilityConfig_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(context.Context))
	})
	return _c
}

func (_c *FeeEstimatorConfigReader_GetDataAvailabilityConfig_Call) Return(destDAOverheadGas int64, destGasPerDAByte int64, destDAMultiplierBps int64, err error) *FeeEstimatorConfigReader_GetDataAvailabilityConfig_Call {
	_c.Call.Return(destDAOverheadGas, destGasPerDAByte, destDAMultiplierBps, err)
	return _c
}

func (_c *FeeEstimatorConfigReader_GetDataAvailabilityConfig_Call) RunAndReturn(run func(context.Context) (int64, int64, int64, error)) *FeeEstimatorConfigReader_GetDataAvailabilityConfig_Call {
	_c.Call.Return(run)
	return _c
}

// ModifyGasPriceComponents provides a mock function with given fields: ctx, execGasPrice, daGasPrice
func (_m *FeeEstimatorConfigReader) ModifyGasPriceComponents(ctx context.Context, execGasPrice *big.Int, daGasPrice *big.Int) (*big.Int, *big.Int, error) {
	ret := _m.Called(ctx, execGasPrice, daGasPrice)

	if len(ret) == 0 {
		panic("no return value specified for ModifyGasPriceComponents")
	}

	var r0 *big.Int
	var r1 *big.Int
	var r2 error
	if rf, ok := ret.Get(0).(func(context.Context, *big.Int, *big.Int) (*big.Int, *big.Int, error)); ok {
		return rf(ctx, execGasPrice, daGasPrice)
	}
	if rf, ok := ret.Get(0).(func(context.Context, *big.Int, *big.Int) *big.Int); ok {
		r0 = rf(ctx, execGasPrice, daGasPrice)
	} else {
		if ret.Get(0) != nil {
			r0 = ret.Get(0).(*big.Int)
		}
	}

	if rf, ok := ret.Get(1).(func(context.Context, *big.Int, *big.Int) *big.Int); ok {
		r1 = rf(ctx, execGasPrice, daGasPrice)
	} else {
		if ret.Get(1) != nil {
			r1 = ret.Get(1).(*big.Int)
		}
	}

	if rf, ok := ret.Get(2).(func(context.Context, *big.Int, *big.Int) error); ok {
		r2 = rf(ctx, execGasPrice, daGasPrice)
	} else {
		r2 = ret.Error(2)
	}

	return r0, r1, r2
}

// FeeEstimatorConfigReader_ModifyGasPriceComponents_Call is a *mock.Call that shadows Run/Return methods with type explicit version for method 'ModifyGasPriceComponents'
type FeeEstimatorConfigReader_ModifyGasPriceComponents_Call struct {
	*mock.Call
}

// ModifyGasPriceComponents is a helper method to define mock.On call
//   - ctx context.Context
//   - execGasPrice *big.Int
//   - daGasPrice *big.Int
func (_e *FeeEstimatorConfigReader_Expecter) ModifyGasPriceComponents(ctx interface{}, execGasPrice interface{}, daGasPrice interface{}) *FeeEstimatorConfigReader_ModifyGasPriceComponents_Call {
	return &FeeEstimatorConfigReader_ModifyGasPriceComponents_Call{Call: _e.mock.On("ModifyGasPriceComponents", ctx, execGasPrice, daGasPrice)}
}

func (_c *FeeEstimatorConfigReader_ModifyGasPriceComponents_Call) Run(run func(ctx context.Context, execGasPrice *big.Int, daGasPrice *big.Int)) *FeeEstimatorConfigReader_ModifyGasPriceComponents_Call {
	_c.Call.Run(func(args mock.Arguments) {
		run(args[0].(context.Context), args[1].(*big.Int), args[2].(*big.Int))
	})
	return _c
}

func (_c *FeeEstimatorConfigReader_ModifyGasPriceComponents_Call) Return(modExecGasPrice *big.Int, modDAGasPrice *big.Int, err error) *FeeEstimatorConfigReader_ModifyGasPriceComponents_Call {
	_c.Call.Return(modExecGasPrice, modDAGasPrice, err)
	return _c
}

func (_c *FeeEstimatorConfigReader_ModifyGasPriceComponents_Call) RunAndReturn(run func(context.Context, *big.Int, *big.Int) (*big.Int, *big.Int, error)) *FeeEstimatorConfigReader_ModifyGasPriceComponents_Call {
	_c.Call.Return(run)
	return _c
}

// NewFeeEstimatorConfigReader creates a new instance of FeeEstimatorConfigReader. It also registers a testing interface on the mock and a cleanup function to assert the mocks expectations.
// The first argument is typically a *testing.T value.
func NewFeeEstimatorConfigReader(t interface {
	mock.TestingT
	Cleanup(func())
}) *FeeEstimatorConfigReader {
	mock := &FeeEstimatorConfigReader{}
	mock.Mock.Test(t)

	t.Cleanup(func() { mock.AssertExpectations(t) })

	return mock
}
