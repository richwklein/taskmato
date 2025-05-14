import { Color } from '@types'

export const berryRed: Color = {
  id: 'berry_red',
  name: 'Berry Red',
  hex: '#b8255f',
} as const
export const red: Color = {
  id: 'red',
  name: 'Red',
  hex: '#db4035',
} as const
export const orange: Color = {
  id: 'orange',
  name: 'Orange',
  hex: '#ff9933',
} as const
export const yellow: Color = {
  id: 'yellow',
  name: 'Yellow',
  hex: '#fad000',
} as const
export const oliveGreen: Color = {
  id: 'olive_green',
  name: 'Olive Green',
  hex: '#afb83b',
} as const
export const limeGreen: Color = {
  id: 'lime_green',
  name: 'Lime Green',
  hex: '#7ecc49',
} as const
export const green: Color = {
  id: 'green',
  name: 'Green',
  hex: '#299438',
} as const
export const mintGreen: Color = {
  id: 'mint_green',
  name: 'Mint Green',
  hex: '#6accbc',
} as const
export const turquoise: Color = {
  id: 'turquoise',
  name: 'Turquoise',
  hex: '#158fad',
} as const
export const skyBlue: Color = {
  id: 'sky_blue',
  name: 'Sky Blue',
  hex: '#14aaf5',
} as const
export const lightBlue: Color = {
  id: 'light_blue',
  name: 'Light Blue',
  hex: '#96c3eb',
} as const
export const blue: Color = {
  id: 'blue',
  name: 'Blue',
  hex: '#4073ff',
} as const
export const grape: Color = {
  id: 'grape',
  name: 'Grape',
  hex: '#884dff',
} as const
export const violet: Color = {
  id: 'violet',
  name: 'Violet',
  hex: '#af38eb',
} as const
export const lavender: Color = {
  id: 'lavender',
  name: 'Lavender',
  hex: '#eb96eb',
} as const
export const magenta: Color = {
  id: 'magenta',
  name: 'Magenta',
  hex: '#e05194',
} as const
export const salmon: Color = {
  id: 'salmon',
  name: 'Salmon',
  hex: '#ff8d85',
} as const
export const charcoal: Color = {
  id: 'charcoal',
  name: 'Charcoal',
  hex: '#808080',
} as const
export const gray: Color = {
  id: 'gray',
  name: 'Gray',
  hex: '#b8b8b8',
} as const
export const taupe: Color = {
  id: 'taupe',
  name: 'Taupe',
  hex: '#ccac93',
} as const

export const colors = [
  berryRed,
  red,
  orange,
  yellow,
  oliveGreen,
  limeGreen,
  green,
  mintGreen,
  turquoise,
  skyBlue,
  lightBlue,
  blue,
  grape,
  violet,
  lavender,
  magenta,
  salmon,
  charcoal,
  gray,
  taupe,
]

/** Default color if another color is not supplied or valid. */
export const defaultColor: Color = charcoal

/**
 * Get a color by an id. If the color is not found, return the default color.
 */
export function getColorById(colorId: string): Color {
  const color = colors.find((color) => color.id === colorId)
  return color ?? defaultColor
}
