build: build@scheduling-api build@scheduling-dashboard-projection

build@scheduling-api:
	mkdir -p dist/scheduling-api
	npx --yes elm-esm make src/Service/SchedulingApi/Main.elm --optimize --output=app.js 
	node js/patches.js app.js
	npx --yes terser app.js --compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe" --mangle --output=app.js
	mv app.js dist/scheduling-api
	cp js/*.js dist/scheduling-api
	
	sed -i -e 's/MAIN/Elm.Service.SchedulingApi.Main/g' dist/scheduling-api/worker.js
	rm -f dist/scheduling-api/*.js-e

build@scheduling-dashboard-projection:
	mkdir -p dist/scheduling-dashboard-projection
	npx --yes elm-esm make src/Service/SchedulingDashboardProjection/Main.elm --optimize --output=app.js 
	node js/patches.js app.js
	npx --yes terser app.js --compress "pure_funcs=[F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9],pure_getters,keep_fargs=false,unsafe_comps,unsafe" --mangle --output=app.js
	mv app.js dist/scheduling-dashboard-projection
	cp js/*.js dist/scheduling-dashboard-projection

	sed -i -e 's/MAIN/Elm.Service.SchedulingDashboardProjection.Main/g' dist/scheduling-dashboard-projection/worker.js
	rm -f dist/scheduling-dashboard-projection/*.js-e

build@backoffice:
	rm -rf dist/backoffice
	cd frontend/backoffice && make release
	cp -R frontend/backoffice/dist dist/backoffice

serve@backend: build
	cd local && npm run serve

serve@frontend:
	cd frontend/backoffice && npm run serve

deploy@scheduling-api: build@scheduling-api
	npx --yes wrangler deploy --config deployment/scheduling-api.wrangler.toml

deploy@scheduling-dashboard-projection: build@scheduling-dashboard-projection
	npx --yes wrangler deploy --config deployment/scheduling-dashboard-projection.wrangler.toml

deploy@backoffice: build@backoffice
	sed -i -e 's|http://127.0.0.1:5000/buckets/scheduling|TODO|g' dist/backoffice/js/app.js
	npx --yes wrangler pages deploy dist/backoffice --project-name backoffice