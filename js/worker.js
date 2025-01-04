import { Elm } from "./app.js";

// export repositories
export { AirfieldRepository } from "./airfield-repository.js"
export { AirshipRepository } from "./airship-repository.js"
export { FlightRepository } from "./flight-repository.js"

// template variables:
// - MAIN = Elm app main entry (e.g. Elm.App.Main)
export default {
    async fetch(request, env) {
        globalThis.env = env;

        const app = MAIN.init();
        const fetchResponse = new Promise(
            app.ports.fetchResponse.subscribe
        );

        const { method, url } = request;
        const contentType = request.headers.get("content-type");        
        const body = contentType.includes("application/json")
            ? await request.json()
            : null;

        const authorization = { scopes: [] };
        const authorizationHeader = request.headers.get("authorization") || "";
        if (authorizationHeader.startsWith("Bearer ")) {
            const token = authorizationHeader.substring(7);
            authorization.scopes = token.split(" ");
        }

        app.ports.fetchRequest.send({ method, url, authorization, body });

        return fetchResponse.then(response => {
            const [status, body] = response;

            return new Response(
                JSON.stringify(body),
                {
                    status: status,
                    headers: {
                        "content-type": "application/json"
                    }
                }
            )
        })
    },

    async queue(batch, env) {
        globalThis.env = env;

        const app = MAIN.init();

        for (let message of batch.messages) {
            const ack = new Promise(app.ports.ack.subscribe);
            const nack = new Promise(app.ports.nack.subscribe);

            const body = JSON.parse(message.body);
            app.ports.receive.send(body);

            await Promise.any([ack, nack]);
        }
    }
}
