// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")
const fs = require("fs")
const path = require("path")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/carddo_web.ex",
    "../lib/carddo_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        brand: "#c14953",
        'jet': {
          DEFAULT: '#2d2d2a',
          100: '#090908',
          200: '#121211',
          300: '#1b1b19',
          400: '#242422',
          500: '#2d2d2a',
          600: '#585853',
          700: '#84847c',
          800: '#adada8',
          900: '#d6d6d3'
        },
        'davys_gray': {
          DEFAULT: '#4c4c47',
          100: '#0f0f0e',
          200: '#1e1e1d',
          300: '#2e2e2b',
          400: '#3d3d39',
          500: '#4c4c47',
          600: '#71716b',
          700: '#96968f',
          800: '#b9b9b4',
          900: '#dcdcda'
        },
        'cool_gray': {
          DEFAULT: '#848fa5',
          100: '#191c22',
          200: '#323844',
          300: '#4b5466',
          400: '#657088',
          500: '#848fa5',
          600: '#9ca5b6',
          700: '#b5bcc8',
          800: '#ced2db',
          900: '#e6e9ed'
        },
        'bittersweet_shimmer': {
          DEFAULT: '#c14953',
          100: '#280e10',
          200: '#4f1b1f',
          300: '#77292f',
          400: '#9e363f',
          500: '#c14953',
          600: '#cd6d75',
          700: '#da9298',
          800: '#e6b6ba',
          900: '#f3dbdd'
        },
        'pearl': {
          DEFAULT: '#e5dcc5',
          100: '#3b321b',
          200: '#766435',
          300: '#b19550',
          400: '#cbb98c',
          500: '#e5dcc5',
          600: '#ebe4d2',
          700: '#f0ebdd',
          800: '#f5f1e8',
          900: '#faf8f4'
        }
      }
    },
  },
  daisyui: {
    logs: false
  },
  plugins: [
    require("daisyui"),
    // Allows prefixing tailwind classes with LiveView classes to add rules
    // only when LiveView classes are applied, for example:
    //
    //     <div class="phx-click-loading:animate-ping">
    //
    plugin(({ addVariant }) => addVariant("phx-no-feedback", [".phx-no-feedback&", ".phx-no-feedback &"])),
    plugin(({ addVariant }) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({ addVariant }) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({ addVariant }) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"])),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle
    // See your `CoreComponents.icon/1` for more information.
    //
    plugin(function({ matchComponents, theme }) {
      let iconsDir = path.join(__dirname, "../deps/heroicons/optimized")
      let values = {}
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
        ["-micro", "/16/solid"]
      ]
      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach(file => {
          let name = path.basename(file, ".svg") + suffix
          values[name] = { name, fullPath: path.join(iconsDir, dir, file) }
        })
      })
      matchComponents({
        "hero": ({ name, fullPath }) => {
          let content = fs.readFileSync(fullPath).toString().replace(/\r?\n|\r/g, "")
          let size = theme("spacing.6")
          if (name.endsWith("-mini")) {
            size = theme("spacing.5")
          } else if (name.endsWith("-micro")) {
            size = theme("spacing.4")
          }
          return {
            [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
            "-webkit-mask": `var(--hero-${name})`,
            "mask": `var(--hero-${name})`,
            "mask-repeat": "no-repeat",
            "background-color": "currentColor",
            "vertical-align": "middle",
            "display": "inline-block",
            "width": size,
            "height": size
          }
        }
      }, { values })
    })
  ]
}
