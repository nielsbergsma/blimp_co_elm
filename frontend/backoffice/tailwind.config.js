/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./src/**/*.{elm,html,js}", "./src/Main.elm", "./index.html"],
  future: {
    hoverOnlyWhenSupported: true
  },
  theme: {
    extend: {},
  },
  plugins: [],
}