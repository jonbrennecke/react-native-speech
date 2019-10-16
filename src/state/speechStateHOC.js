// @flow
import React from 'react';
import { connect } from 'react-redux';
import identity from 'lodash/identity';

import type { ComponentType } from 'react';

import type { Dispatch } from '../types';
import type { ISpeechState } from './';

type OwnProps = {};

type StateProps = {};

type DispatchProps = {};

export type SpeechStateHOCProps = OwnProps & StateProps & DispatchProps;

function mapCameraStateToProps(state: ISpeechState): $Exact<StateProps> {
  return {};
}

function mapCameraDispatchToProps(
  dispatch: Dispatch<any>
): $Exact<DispatchProps> {
  return {};
}

const createSlicedStateToPropsMapper = <State, StateSlice, StateProps>(
  mapStateToProps: StateSlice => StateProps,
  stateSliceAccessor?: State => StateSlice = identity
): ((state: State) => StateProps) => {
  return state => {
    const stateSlice = stateSliceAccessor(state);
    return mapStateToProps(stateSlice);
  };
};

const createSlicedDispatchToPropsMapper = <State, StateSlice, DispatchProps>(
  mapDispatchToProps: (Dispatch<*>, () => StateSlice) => DispatchProps,
  stateSliceAccessor?: State => StateSlice = identity
): ((dispatch: Dispatch<*>, getState: () => State) => DispatchProps) => {
  return (dispatch, getState) => {
    const getSlicedSlice = () => stateSliceAccessor(getState());
    return mapDispatchToProps(dispatch, getSlicedSlice);
  };
};

export type CameraStateHOC<OriginalProps> = (
  Component: ComponentType<SpeechStateHOCProps & OriginalProps>
) => ComponentType<OriginalProps>;

export function createCameraStateHOC<PassThroughProps, State: ISpeechState>(
  stateSliceAccessor?: State => ISpeechState = identity
): CameraStateHOC<PassThroughProps> {
  const mapStateToProps = createSlicedStateToPropsMapper(
    mapCameraStateToProps,
    stateSliceAccessor
  );
  const mapDispatchToProps = createSlicedDispatchToPropsMapper(
    mapCameraDispatchToProps,
    stateSliceAccessor
  );
  return Component => {
    const fn = (props: PassThroughProps) => <Component {...props} />;
    return connect(mapStateToProps, mapDispatchToProps)(fn);
  };
}
