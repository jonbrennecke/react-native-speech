// @flow
import { Record } from 'immutable';

import type { RecordOf, RecordInstance } from 'immutable';

export type SpeechStateObject = {};

export type SpeechStateRecord = RecordOf<SpeechStateObject>;

export interface ISpeechState {}

// eslint-disable-next-line flowtype/generic-spacing
export const createCameraState: SpeechStateObject => Class<
  RecordInstance<SpeechStateRecord> & ISpeechState
> = defaultState =>
  class SpeechState extends Record(defaultState) implements ISpeechState {};
