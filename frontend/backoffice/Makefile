debug:
	rm -rf dist/
	mkdir -p dist

	npx --yes elm make src/Main.elm --debug --output=dist/js/app.js
	cat js/components.js >> dist/js/app.js

	cp -R css dist
	cp -R img dist
	cp -R js dist
	npx tailwindcss -i ./css/app.css -o ./dist/css/app.css

	cp index.html dist/

release:
	rm -rf dist/
	mkdir -p dist

	npx --yes elm make src/Main.elm --optimize --output=dist/js/app.js
	cat js/components.js >> dist/js/app.js

	npx terser dist/js/app.js --compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe" --mangle --output=dist/js/app.js

	cp -R css dist
	cp -R img dist
	cp -R js dist
	npx tailwindcss -i ./css/app.css --minify -o ./dist/css/app.css

	cp index.html dist/


serve: debug
	npm run serve