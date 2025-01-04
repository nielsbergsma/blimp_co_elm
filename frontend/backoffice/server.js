const http = require("http");
const fs = require("fs").promises;

const host = '127.0.0.1';
const port = 5001;

const pagePaths = [
    "",
    "/",
    "/flight-scheduling",
    "/reservations"
];

const mimeTypesPerExtension = {
    ".js": "text/javascript",
    ".html": "text/html",
    ".css": "text/css",
    ".webp": "image/webp",
    ".svg": "image/svg",
}

function getContentType(path) {
    for (const [key, value] of Object.entries(mimeTypesPerExtension)) {
        if (path.endsWith(key)) {
            return value;
        }
    }
    return "application/octet-stream"
}

async function handler(request, response) {
    if (pagePaths.includes(request.url)) {
        request.url = "/index.html"
    }

    try {
        const path = `dist${decodeURIComponent(request.url)}`;
        const content = await fs.readFile(path);
        
        response.setHeader("Content-Type", getContentType(path));
        response.end(content);
    } catch (exception) {
        console.error(exception);
        response.writeHead(404, { "Content-Type": "text/plain" });
        response.end("not found");
    }
};

const server = http.createServer(handler);
server.listen(port, host, () => {
    console.log(`server is running on http://${host}:${port}`);
});
