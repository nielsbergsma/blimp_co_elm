import { Miniflare,Log, LogLevel } from "miniflare";

export function serve() {
    return new Miniflare({
        log: new Log(LogLevel.DEBUG),
        port: 5000,
        workers: [
            {
                name: "scheduling-api",
                modules: true,
                modulesRules: [
                    { type: "ESModule", include: ["**/*.js"] },
                ],
                scriptPath: "dist/scheduling-api/worker.js",
                routes: ["http://127.0.0.1/airfields", "http://127.0.0.1/airships", "http://127.0.0.1/flights"],
                queueProducers: {                    
                    scheduling_queue: "scheduling-queue"
                },
                durableObjects: {
                    airfields: "AirfieldRepository",
                    airships: "AirshipRepository",
                    flights: "FlightRepository"
                },
                compatibilityFlags: ["nodejs_compat"],
                compatibilityDate: "2024-09-23"
            },
            {
                name: "scheduling-dashboard-projection",
                modules: true,
                modulesRules: [
                    { type: "ESModule", include: ["**/*.js"] },
                ],
                scriptPath: "dist/scheduling-dashboard-projection/worker.js",
                queueConsumers: {
                    "scheduling-queue": {
                        maxBatchSize: 5,
                        maxBatchTimeout: 1,
                        maxRetries: 1,
                        deadLetterQueue: "scheduling-queue-dlq"
                    }
                },
                r2Buckets: ["scheduling_bucket"],
                compatibilityFlags: ["nodejs_compat"],
                compatibilityDate: "2024-09-23"
            },
            {
                name: "buckets",
                routes: ["http://127.0.0.1/buckets/scheduling/dashboard"],
                modules: true,
                script: `
                  export default {
                    async fetch(request, env, ctx) {
                      const url = new URL(request.url);
                      const path = url.pathname.split("/");
                      const bucket = path[2] + "_bucket";
                      const resource = path.slice(3).join("/");
                      
                      const object = await env[bucket].get(resource);
                      if (object) {
                        const value = await object.json();
                        return Response.json(value);
                      }
                      else {
                        return Response.json({ error: "not found"}, { status: 404 })
                      }
                    }
                  }
                `,
                r2Buckets: ["scheduling_bucket"],
            },
            {
                name: "backoffice_site",
                routes: ["http://127.0.0.1/flight-scheduling", "http://127.0.0.1/reservations", "http://127.0.0.1/img/*", "http://127.0.0.1/js/*", "http://127.0.0.1/css/*"],
                modules: true,
                script: `
                    export default {
                        async fetch(request, env, ctx) {
                            const url = new URL(request.url);
                            return await fetch("http://localhost:5001" + url.pathname.replace("/backoffice", ""));
                        }
                    }
                `,
                r2Buckets: ["scheduling_bucket"],
            } 
        ]
    });
}

export async function teardown(instance) {
    await instance.dispose();
}


serve();