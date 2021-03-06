// @flow
import React, { PureComponent } from 'react';
import { connect } from 'react-redux';
import identity from 'lodash/identity';
import { autobind } from 'core-decorators';
import { Set } from 'immutable';

import {
  SpeechTranscriptionEvents,
  SpeechTranscriptionEventEmitter,
  getCurrentLocale,
  getSupportedLocales,
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
  LocaleObject,
} from './';

type OwnProps = {};

type StateProps = {
  speechTranscriptionAvailability: boolean,
  speechTranscriptionStatus: SpeechTranscriptionStatus,
  speechTranscriptions: ImmutableMap<string, SpeechTranscription>,
  speechTranscriptionErrors: ImmutableMap<string, SpeechTranscriptionError>,
  speechTranscriptionIDsWithNoSpeechDetected: Set<string>,
  locale: ?LocaleObject,
  supportedLocales: Set<LocaleObject>,
};

type DispatchProps = {
  setSpeechTranscriptionAvailability: boolean => DispatchAction<any>,
  // eslint-disable-next-line flowtype/generic-spacing
  setSpeechTranscriptionStatus: SpeechTranscriptionStatus => DispatchAction<
    any
  >,
  setSpeechTranscription: (
    assetID: string,
    speechTranscription: SpeechTranscription
  ) => DispatchAction<any>,
  setSpeechTranscriptionError: (
    assetID: string,
    error: SpeechTranscriptionError
  ) => DispatchAction<any>,
  setSpeechTranscriptionIDWithNoSpeechDetected: (
    assetID: string
  ) => DispatchAction<any>,
  setLocale: (locale: LocaleObject) => DispatchAction<any>,
  setSupportedLocales: (
    supportedLocales: Set<LocaleObject>
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
    speechTranscriptionIDsWithNoSpeechDetected: selectors.selectSpeechTranscriptionIDsWithNoSpeechDetected(
      state
    ),
    locale: selectors.selectLocale(state),
    supportedLocales: selectors.selectSupportedLocales(state),
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
      assetID: string,
      speechTranscription: SpeechTranscription
    ) =>
      dispatch(
        actionCreators.setSpeechTranscription({ assetID, speechTranscription })
      ),
    setSpeechTranscriptionError: (
      assetID: string,
      error: SpeechTranscriptionError
    ) =>
      dispatch(
        actionCreators.setSpeechTranscriptionError({
          assetID,
          speechTranscriptionError: error,
        })
      ),
    setSpeechTranscriptionIDWithNoSpeechDetected: (assetID: string) =>
      dispatch(
        actionCreators.setSpeechTranscriptionIDWithNoSpeechDetected({
          assetID,
        })
      ),
    setLocale: (locale: LocaleObject) =>
      dispatch(
        actionCreators.setLocale({
          locale,
        })
      ),
    setSupportedLocales: (supportedLocales: Set<LocaleObject>) =>
      dispatch(
        actionCreators.setSupportedLocales({
          supportedLocales,
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

      async componentDidMount() {
        this.addSpeechTranscriptionEventListeners();
        const currentLocale = await getCurrentLocale();
        this.props.setLocale(currentLocale);
        const supportedLocales = await getSupportedLocales();
        this.props.setSupportedLocales(Set(supportedLocales));
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
        this.eventListeners.set(
          'didChangeLocale',
          SpeechTranscriptionEventEmitter.addListener(
            SpeechTranscriptionEvents.didChangeLocale,
            this.speechTranscriptionDidChangeLocale
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
        const status = this.props.speechTranscriptionStatus;
        if (status) {
          const { currentAssetID } = status;
          this.props.setSpeechTranscriptionError(currentAssetID, true);
        }
        this.props.setSpeechTranscriptionStatus(null);
      }

      speechTranscriptionDidNotDetectSpeech() {
        const status = this.props.speechTranscriptionStatus;
        if (status) {
          const { currentAssetID } = status;
          this.props.setSpeechTranscriptionIDWithNoSpeechDetected(
            currentAssetID
          );
        }
      }

      speechTranscriptionDidChangeLocale(locale: LocaleObject) {
        this.props.setLocale(locale);
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
