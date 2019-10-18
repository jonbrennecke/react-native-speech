// @flow
import React, { PureComponent } from 'react';
import { SafeAreaView, Button, Text } from 'react-native';
import { storiesOf } from '@storybook/react-native';
import { withKnobs } from '@storybook/addon-knobs';
import { Provider } from 'react-redux';
import {
  authorizeMediaLibrary,
  createMediaStateHOC,
} from '@jonbrennecke/react-native-media';
import {
  beginSpeechTranscriptionOfAsset,
  createSpeechStateHOC,
  requestSpeechPermissions,
} from '@jonbrennecke/react-native-speech';

import { createReduxStore } from './speechStore';

import type { MediaStateHOCProps } from '@jonbrennecke/react-native-media';
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

const wrapWithMediaState = createMediaStateHOC(state => state.media);
const wrapWithSpeechState = createSpeechStateHOC(state => state.speech);

type StoryComponentOwnProps = {};

type StoryComponentProps = StoryComponentOwnProps &
  SpeechStateHOCProps &
  MediaStateHOCProps;

class StoryComponent extends PureComponent<StoryComponentProps> {
  async componentDidMount() {
    await authorizeMediaLibrary();
    await requestSpeechPermissions();
    await this.props.queryMedia({ mediaType: 'video', limit: 1 });
  }

  render() {
    const start = async () => {
      if (!this.props.assets.size) {
        throw 'Could not find a video';
      }
      const asset = this.props.assets.first();
      await beginSpeechTranscriptionOfAsset(asset.assetID);
    };
    var formattedString: ?string = null;
    var noSpeechDetected = false;
    var failedToTranscribe = false;
    if (this.props.assets.size) {
      const asset = this.props.assets.first();
      const transcription = this.props.speechTranscriptions.get(asset.assetID);
      if (transcription) {
        formattedString = transcription.formattedString;
      }
      failedToTranscribe = this.props.speechTranscriptionErrors.has(
        asset.assetID
      );
      noSpeechDetected = this.props.speechTranscriptionIDsWithNoSpeechDetected.has(
        asset.assetID
      );
    }
    const disabled =
      !!this.props.speechTranscriptionStatus ||
      !this.props.speechTranscriptionAvailability;
    return (
      <SafeAreaView style={styles.center}>
        <Button
          disabled={disabled}
          title="Transcribe audio file"
          onPress={start}
        />
        {formattedString && <Text>{formattedString}</Text>}
        {noSpeechDetected && <Text>Error: No speech detected</Text>}
        {failedToTranscribe && <Text>Error: Failed to transcribe</Text>}
      </SafeAreaView>
    );
  }
}

const Component = wrapWithMediaState(wrapWithSpeechState(StoryComponent));

const stories = storiesOf('Speech', module);
stories.addDecorator(withKnobs);
stories.add('Recorded Audio', () => (
  <Provider store={store}>
    <Component />
  </Provider>
));
