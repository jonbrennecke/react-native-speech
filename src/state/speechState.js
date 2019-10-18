// @flow
import { Record } from 'immutable';

import type { RecordOf, RecordInstance, Map, Set } from 'immutable';

export type SpeechTranscriptionStatus = ?{ currentAssetID: string };

export type SpeechTranscriptionSegment = {
  duration: number,
  timestamp: number,
  confidence: number,
  substring: string,
  alternativeSubstrings: string[],
};

export type SpeechTranscription = {
  isFinal: boolean,
  formattedString: string,
  segments: SpeechTranscriptionSegment[],
  locale: LocaleObject,
};

export type LocaleObject = {
  language: {
    code: string,
    localizedStrings: {
      languageLocale: string,
      currentLocale: string,
    },
  },
  country: {
    code: string,
    localizedStrings: {
      languageLocale: string,
      currentLocale: string,
    },
  },
};

export type SpeechTranscriptionError = any; // TODO

export type SpeechStateObject = {
  speechTranscriptionStatus: SpeechTranscriptionStatus,
  speechTranscriptionAvailability: boolean,
  speechTranscriptions: Map<string, SpeechTranscription>,
  speechTranscriptionErrors: Map<string, SpeechTranscriptionError>,
  speechTranscriptionIDsWithNoSpeechDetected: Set<string>,
};

export type SpeechStateRecord = RecordOf<SpeechStateObject>;

export interface ISpeechState {
  getSpeechTranscriptionStatus(): SpeechTranscriptionStatus;
  setSpeechTranscriptionStatus(status: SpeechTranscriptionStatus): ISpeechState;

  getSpeechTranscriptionAvailability(): boolean;
  setSpeechTranscriptionAvailability(available: boolean): ISpeechState;

  getSpeechTranscriptions(): Map<string, SpeechTranscription>;
  setSpeechTranscriptions(
    speechTranscriptions: Map<string, SpeechTranscription>
  ): ISpeechState;
  setSpeechTranscription(
    assetID: string,
    speechTranscription: SpeechTranscription
  ): ISpeechState;

  getSpeechTranscriptionErrors(): Map<string, SpeechTranscriptionError>;
  setSpeechTranscriptionErrors(
    errors: Map<string, SpeechTranscriptionError>
  ): ISpeechState;
  setSpeechTranscriptionError(
    assetID: string,
    error: SpeechTranscriptionError
  ): ISpeechState;

  getSpeechTranscriptionIDsWithNoSpeechDetected(): Set<string>;
  setSpeechTranscriptionIDsWithNoSpeechDetected(
    assetIDs: Set<string>
  ): ISpeechState;
  setSpeechTranscriptionIDWithNoSpeechDetected(assetID: string): ISpeechState;
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

    getSpeechTranscriptions(): Map<string, SpeechTranscription> {
      return this.get('speechTranscriptions');
    }

    setSpeechTranscriptions(
      speechTranscriptions: Map<string, SpeechTranscription>
    ): ISpeechState {
      return this.set('speechTranscriptions', speechTranscriptions);
    }

    setSpeechTranscription(
      assetID: string,
      speechTranscription: SpeechTranscription
    ): ISpeechState {
      const speechTranscriptions = this.getSpeechTranscriptions();
      return this.setSpeechTranscriptions(
        speechTranscriptions.set(assetID, speechTranscription)
      );
    }

    getSpeechTranscriptionErrors(): Map<string, SpeechTranscriptionError> {
      return this.get('speechTranscriptionErrors');
    }

    setSpeechTranscriptionErrors(
      errors: Map<string, SpeechTranscriptionError>
    ): ISpeechState {
      return this.set('speechTranscriptionErrors', errors);
    }

    setSpeechTranscriptionError(
      assetID: string,
      error: SpeechTranscriptionError
    ): ISpeechState {
      const errors = this.getSpeechTranscriptionErrors();
      return this.setSpeechTranscriptionErrors(errors.set(assetID, error));
    }

    getSpeechTranscriptionIDsWithNoSpeechDetected(): Set<string> {
      return this.get('speechTranscriptionIDsWithNoSpeechDetected');
    }

    setSpeechTranscriptionIDsWithNoSpeechDetected(
      speechTranscriptionIDsWithNoSpeechDetected: Set<string>
    ): ISpeechState {
      return this.set(
        'speechTranscriptionIDsWithNoSpeechDetected',
        speechTranscriptionIDsWithNoSpeechDetected
      );
    }

    setSpeechTranscriptionIDWithNoSpeechDetected(
      assetID: string
    ): ISpeechState {
      const assetIDs = this.getSpeechTranscriptionIDsWithNoSpeechDetected();
      return this.setSpeechTranscriptionIDsWithNoSpeechDetected(
        assetIDs.add(assetID)
      );
    }
  };
