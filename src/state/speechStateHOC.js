// @flow
import React, { PureComponent } from 'react';
import { connect } from 'react-redux';
import identity from 'lodash/identity';
import { autobind } from 'core-decorators';

import {
  SpeechTranscriptionEvents,
  SpeechTranscriptionEventEmitter,
} from '../utils';
import { actionCreators } from './speechActionCreators';
import { selectors } from './speechSelectors';

import type { ComponentType } from 'react';
import type { Map as ImmutableMap } from 'immutable';

import type { Dispatch, ReturnType, DispatchAction } from '../types';
import type {
  ISpeechState,
  SpeechTranscriptionStatus,
  SpeechTranscription,
  SpeechTranscriptionError,
} from './';

type OwnProps = {};

type StateProps = {
  speechTranscriptionAvailability: boolean,
  speechTranscriptionStatus: SpeechTranscriptionStatus,
  speechTranscriptions: ImmutableMap<string, SpeechTranscription>,
  speechTranscriptionErrors: ImmutableMap<string, SpeechTranscriptionError>,
};

type DispatchProps = {
  setSpeechTranscriptionAvailability: boolean => DispatchAction<any>,
  // eslint-disable-next-line flowtype/generic-spacing
  setSpeechTranscriptionStatus: SpeechTranscriptionStatus => DispatchAction<
    any
  >,
  setSpeechTranscription: (
    key: string,
    speechTranscription: SpeechTranscription
  ) => DispatchAction<any>,
  setSpeechTranscriptionError: (
    key: string,
    error: SpeechTranscriptionError
  ) => DispatchAction<any>,
};

export type SpeechStateHOCProps = OwnProps & StateProps & DispatchProps;

function mapCameraStateToProps(state: ISpeechState): $Exact<StateProps> {
  return {
    speechTranscriptionAvailability: selectors.selectSpeechTranscriptionAvailability(
      state
    ),
    speechTranscriptionStatus: selectors.selectSpeechTranscriptionStatus(state),
    speechTranscriptions: selectors.selectSpeechTranscriptions(state),
    speechTranscriptionErrors: selectors.selectSpeechTranscriptionErrors(state),
  };
}

function mapCameraDispatchToProps(
  dispatch: Dispatch<any>
): $Exact<DispatchProps> {
  return {
    setSpeechTranscriptionAvailability: available =>
      dispatch(
        actionCreators.setSpeechTranscriptionAvailability({ available })
      ),
    setSpeechTranscriptionStatus: status =>
      dispatch(actionCreators.setSpeechTranscriptionStatus({ status })),
    setSpeechTranscription: (
      key: string,
      speechTranscription: SpeechTranscription
    ) =>
      dispatch(
        actionCreators.setSpeechTranscription({ key, speechTranscription })
      ),
    setSpeechTranscriptionError: (
      key: string,
      error: SpeechTranscriptionError
    ) =>
      dispatch(
        actionCreators.setSpeechTranscriptionError({
          key,
          speechTranscriptionError: error,
        })
      ),
  };
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

export type SpeechStateHOC<PassThroughProps> = (
  Component: ComponentType<SpeechStateHOCProps & PassThroughProps>
) => ComponentType<PassThroughProps>;

export function createSpeechStateHOC<PassThroughProps, State: ISpeechState>(
  stateSliceAccessor?: State => ISpeechState = identity
): SpeechStateHOC<PassThroughProps> {
  const mapStateToProps = createSlicedStateToPropsMapper(
    mapCameraStateToProps,
    stateSliceAccessor
  );
  const mapDispatchToProps = createSlicedDispatchToPropsMapper(
    mapCameraDispatchToProps,
    stateSliceAccessor
  );

  return WrappedComponent => {
    // $FlowFixMe
    @autobind
    class SpeechScreenStateComponent extends PureComponent<
      SpeechStateHOCProps & PassThroughProps
    > {
      // eslint-disable-next-line flowtype/generic-spacing
      eventListeners: Map<
        $Keys<typeof SpeechTranscriptionEvents>,
        ReturnType<typeof SpeechTranscriptionEventEmitter.addListener>
      > = new Map();

      componentDidMount() {
        this.addSpeechTranscriptionEventListeners();
      }

      componentWillUnmount() {
        this.removeSpeechTranscriptionEventListeners();
      }

      addSpeechTranscriptionEventListeners() {
        this.eventListeners.set(
          'didBecomeAvailable',
          SpeechTranscriptionEventEmitter.addListener(
            SpeechTranscriptionEvents.didBecomeAvailable,
            this.speechTranscriptionDidBecomeAvailable
          )
        );
        this.eventListeners.set(
          'didBecomeUnavailable',
          SpeechTranscriptionEventEmitter.addListener(
            SpeechTranscriptionEvents.didBecomeUnavailable,
            this.speechTranscriptionDidBecomeUnavailable
          )
        );
        this.eventListeners.set(
          'didBegin',
          SpeechTranscriptionEventEmitter.addListener(
            SpeechTranscriptionEvents.didBegin,
            this.speechTranscriptionDidBegin
          )
        );
        this.eventListeners.set(
          'didEnd',
          SpeechTranscriptionEventEmitter.addListener(
            SpeechTranscriptionEvents.didEnd,
            this.speechTranscriptionDidEnd
          )
        );
        this.eventListeners.set(
          'didOutput',
          SpeechTranscriptionEventEmitter.addListener(
            SpeechTranscriptionEvents.didOutput,
            this.speechTranscriptionDidOutput
          )
        );
        this.eventListeners.set(
          'didFail',
          SpeechTranscriptionEventEmitter.addListener(
            SpeechTranscriptionEvents.didFail,
            this.speechTranscriptionDidFail
          )
        );
        this.eventListeners.set(
          'didNotDetectSpeech',
          SpeechTranscriptionEventEmitter.addListener(
            SpeechTranscriptionEvents.didNotDetectSpeech,
            this.speechTranscriptionDidNotDetectSpeech
          )
        );
      }

      removeSpeechTranscriptionEventListeners() {
        this.eventListeners.forEach(eventListener => {
          eventListener.remove();
        });
      }

      speechTranscriptionDidBecomeAvailable() {
        this.props.setSpeechTranscriptionAvailability(true);
      }

      speechTranscriptionDidBecomeUnavailable() {
        this.props.setSpeechTranscriptionAvailability(false);
      }

      speechTranscriptionDidBegin(assetID: string) {
        this.props.setSpeechTranscriptionStatus({ currentAssetID: assetID });
      }

      speechTranscriptionDidEnd() {
        this.props.setSpeechTranscriptionStatus(null);
      }

      speechTranscriptionDidOutput(transcription: SpeechTranscription) {
        const status = this.props.speechTranscriptionStatus;
        if (status) {
          const { currentAssetID } = status;
          this.props.setSpeechTranscription(currentAssetID, transcription);
        }
      }

      speechTranscriptionDidFail() {
        this.props.setSpeechTranscriptionStatus(null);
        const status = this.props.speechTranscriptionStatus;
        if (status) {
          const { currentAssetID } = status;
          this.props.setSpeechTranscriptionError(currentAssetID, true);
        }
      }

      speechTranscriptionDidNotDetectSpeech() {
        console.log('no speech detected');
      }

      render() {
        return <WrappedComponent {...this.props} />;
      }
    }

    return connect(mapStateToProps, mapDispatchToProps)(
      SpeechScreenStateComponent
    );
  };
}
