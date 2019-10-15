// @flow
import { PureComponent } from 'react';

import type { Element } from 'react';

export type StorybookAsyncWrapperProps<T> = {
  loadAsync: () => Promise<T>,
  render: (data: ?T) => ?Element<*>,
};

export type StorybookAsyncWrapperState<T> = {
  data: ?T,
};

export class StorybookAsyncWrapper<T> extends PureComponent<
  StorybookAsyncWrapperProps<T>,
  StorybookAsyncWrapperState<T>
> {
  state: StorybookAsyncWrapperState<T> = {
    data: null,
  };

  async componentDidMount() {
    const data = await this.props.loadAsync();
    this.setState({ data });
  }

  render() {
    return this.props.render(this.state.data) || null;
  }
}
