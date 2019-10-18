// @flow
import React, { PureComponent } from 'react';
import { SafeAreaView, ScrollView, Text, TouchableOpacity } from 'react-native';
import { storiesOf } from '@storybook/react-native';
import { withKnobs } from '@storybook/addon-knobs';
import { Provider } from 'react-redux';
import {
  createSpeechStateHOC,
  requestSpeechPermissions,
  getLocaleID,
  setSpeechLocale
} from '@jonbrennecke/react-native-speech';

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
    return (
      <SafeAreaView style={styles.center}>
        <ScrollView style={styles.flex}>
          {this.props.supportedLocales.toArray().map(locale => (
            <TouchableOpacity
              key={getLocaleID(locale)}
              onPress={() => setSpeechLocale(getLocaleID(locale))}
            >
              <Text style={{
                fontWeight: getLocaleID(locale) === getLocaleID(this.props.locale)
                  ? 'bold' : 'normal'
              }}>
                {locale.language.localizedStrings.currentLocale}
              </Text>
            </TouchableOpacity>
          ))}
        </ScrollView>
      </SafeAreaView>
    );
  }
}

const Component = wrapWithSpeechState(StoryComponent);

const stories = storiesOf('Speech', module);
stories.addDecorator(withKnobs);
stories.add('Locale', () => (
  <Provider store={store}>
    <Component />
  </Provider>
));
