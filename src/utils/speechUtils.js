// @flow
import Bluebird from 'bluebird';
import { NativeModules, NativeEventEmitter } from 'react-native';

const { HSSpeechManager: NativeSpeechManager } = NativeModules;

export const SpeechManager = Bluebird.promisifyAll(NativeSpeechManager);

export const SpeechManagerEventEmitter = new NativeEventEmitter(
  NativeSpeechManager
);

export const SpeechManagerEvents = {
  didBecomeAvailable: 'speechManagerDidBecomeAvailable',
  didBecomeUnavailable: 'speechManagerDidBecomeUnavailable',
  didChangeLocale: 'speechManagerDidChangeLocale',
  didReceiveSpeechTranscription: 'speechManagerDidReceiveSpeechTranscription',
  didNotDetectSpeech: 'speechManagerDidNotDetectSpeech',
  didEnd: 'speechManagerDidEnd',
  didFail: 'speechManagerDidFail',
};

export const beginSpeechTranscriptionOfAsset = async (
  assetID: string
): Promise<boolean> => {
  return SpeechManager.beginSpeechTranscriptionOfAssetAsync(assetID);
};

export const beginSpeechTranscriptionOfAudioSession = async (): Promise<
  boolean
> => {
  return SpeechManager.beginSpeechTranscriptionOfAudioSessionAsync();
};

export const endSpeechTranscriptionOfAudioSession = async (): Promise<
  boolean
> => {
  return SpeechManager.endSpeechTranscriptionOfAudioSessionAsync();
};
