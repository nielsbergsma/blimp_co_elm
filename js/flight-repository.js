import { DurableObject } from "cloudflare:workers";

export class FlightRepository extends DurableObject {
    async get(key) {
        const value = await this.ctx.storage.get(key);
        return value?.value || null;
    }

    async begin(key) {
        const value = await this.ctx.storage.get(key);
        if (value === undefined) {
            return { empty: { key } };
        }
        else {
            return { existing: { ...value, key } };
        }
    }

    async commit(key, version, value) {
        if (typeof version !== "number") {
            version = parseInt(version, 10);
        }

        const existingValue = await this.ctx.storage.get(key);
        const existingVersion = existingValue === undefined ? 0 : existingValue.version;
        if (existingVersion !== version) {
            return { versionConflict: { key, version, value } };
        }
        else {
            version += 1
            await this.ctx.storage.put(key, { version, value });
            return { committed: { key, version, value } };
        }
    }
}