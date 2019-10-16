// @flow
import { createStore, applyMiddleware, combineReducers } from 'redux';
import * as storage from 'redux-storage';
import immutableMerger from 'redux-storage-merger-immutablejs';
import thunkMiddleware from 'redux-thunk';
import { createLogger } from 'redux-logger';
import { reducer as speechReducer } from '@jonbrennecke/react-native-speech';

const isProduction = process.env.NODE_ENV === 'production';

const loggerMiddleware = createLogger({
  collapsed: (getState, action) => !action.error,
});

const reducer = combineReducers({
  speech: speechReducer,
});

const rootReducer = storage.reducer(reducer, immutableMerger);

const middleware = isProduction
  ? applyMiddleware(thunkMiddleware)
  : applyMiddleware(thunkMiddleware, loggerMiddleware);

export const createReduxStore = () => {
  return createStore(rootReducer, middleware);
};
