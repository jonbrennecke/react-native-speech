// @flow
import React, { PureComponent } from 'react';
import { SafeAreaView, Button, Text } from 'react-native';
import { storiesOf } from '@storybook/react-native';
import { withKnobs } from '@storybook/addon-knobs';
import { Provider } from 'react-redux';
import {
  beginSpeechTranscriptionOfAudioSession,
  endSpeechTranscriptionOfAudioSession,
  createSpeechStateHOC,
  requestSpeechPermissions,
} from '@jonbrennecke/react-native-speech';
import makeUniqueId from 'lodash/uniqueId';

import { createReduxStore } from './speechStore';

import type { SpeechStateHOCProps } from '@jonbrennecke/react-native-speech';

const styles = {
  flex: {
    flex: 1,
  },
  center: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
};

const store = createReduxStore();

const wrapWithSpeechState = createSpeechStateHOC(state => state.speech);

type StoryComponentOwnProps = {};

type StoryComponentProps = StoryComponentOwnProps & SpeechStateHOCProps;

type StoryComponentState = {
  uniqueID: ?string,
};

class StoryComponent extends PureComponent<
  StoryComponentProps,
  StoryComponentState
> {
  state = {
    uniqueID: null,
  };

  async componentDidMount() {
    await requestSpeechPermissions();
  }

  render() {
    const start = async () => {
      const uniqueID = makeUniqueId();
      this.setState({ uniqueID });
      await beginSpeechTranscriptionOfAudioSession(uniqueID);
    };
    const stop = async () => {
      await endSpeechTranscriptionOfAudioSession();
    };
    var formattedString: ?string = null;
    var noSpeechDetected = false;
    var failedToTranscribe = false;
    const { uniqueID } = this.state;
    if (uniqueID) {
      const transcription = this.props.speechTranscriptions.get(uniqueID);
      if (transcription) {
        formattedString = transcription.formattedString;
      }
      failedToTranscribe = this.props.speechTranscriptionErrors.has(uniqueID);
      noSpeechDetected = this.props.speechTranscriptionIDsWithNoSpeechDetected.has(
        uniqueID
      );
    }
    const isRecording = !!this.props.speechTranscriptionStatus;
    const isAvailable = this.props.speechTranscriptionAvailability;
    const disabled = isRecording || !isAvailable;
    return (
      <SafeAreaView style={styles.center}>
        <Button
          disabled={disabled}
          title="Transcribe live audio"
          onPress={start}
        />
        {isRecording && (
          <Button
            disabled={!isRecording || !isAvailable}
            title="Stop transcription"
            onPress={stop}
          />
        )}
        {formattedString && <Text>{formattedString}</Text>}
        {noSpeechDetected && <Text>Error: No speech detected</Text>}
        {failedToTranscribe && <Text>Error: Failed to transcribe</Text>}
      </SafeAreaView>
    );
  }
}

const Component = wrapWithSpeechState(StoryComponent);

const stories = storiesOf('Speech', module);
stories.addDecorator(withKnobs);
stories.add('Live Audio', () => (
  <Provider store={store}>
    <Component />
  </Provider>
));
