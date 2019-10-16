// @flow
import { Record } from 'immutable';

import type { RecordOf, RecordInstance } from 'immutable';

export type SpeechTranscriptionStatus = 'ready' | 'transcribing';

export type SpeechStateObject = {
  speechTranscriptionStatus: SpeechTranscriptionStatus,
  speechTranscriptionAvailability: boolean,
};

export type SpeechStateRecord = RecordOf<SpeechStateObject>;

export interface ISpeechState {
  getSpeechTranscriptionStatus(): SpeechTranscriptionStatus;
  setSpeechTranscriptionStatus(status: SpeechTranscriptionStatus): ISpeechState;

  getSpeechTranscriptionAvailability(): boolean;
  setSpeechTranscriptionAvailability(available: boolean): ISpeechState;
}

// eslint-disable-next-line flowtype/generic-spacing
export const createSpeechState: SpeechStateObject => Class<
  RecordInstance<SpeechStateRecord> & ISpeechState
> = defaultState =>
  class SpeechState extends Record(defaultState) implements ISpeechState {
    getSpeechTranscriptionStatus(): SpeechTranscriptionStatus {
      return this.get('speechTranscriptionStatus');
    }

    setSpeechTranscriptionStatus(
      status: SpeechTranscriptionStatus
    ): ISpeechState {
      return this.set('speechTranscriptionStatus', status);
    }

    getSpeechTranscriptionAvailability(): boolean {
      return !!this.get('speechTranscriptionAvailability');
    }

    setSpeechTranscriptionAvailability(available: boolean): ISpeechState {
      return this.set('speechTranscriptionAvailability', available);
    }
  };
