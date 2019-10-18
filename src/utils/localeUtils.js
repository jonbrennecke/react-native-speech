// @flow
import type { LocaleObject } from '../state';

export function getLocaleID(locale: LocaleObject): string {
  return `${locale.language.code}_${locale.country.code.toUpperCase()}`;
}
