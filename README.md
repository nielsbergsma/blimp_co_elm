# Blimp&Co - Elm  

This repository contains the source code accompanying a Medium article. The article explores how to apply Domain-Driven Design in an edge-computing environment. The project consists of two backend services and a frontend web application, all written in [Elm](https://elm-lang.org/).  

## Repository Structure  

This repository is organized as a monorepo. Services import only the bounded context they require and add runtime-specific implementations (e.g., for repositories). Dead Code Elimination (DCE) of the Elm compiler ensures that unused code is removed from the transpiled sources.  

- The [frontend](frontend) folder contains the source code for the web application. [Tailwind CSS](https://tailwindcss.com/) is used for styling.  

- The [local](local) folder includes scripts to run both the frontend and backend locally. The backend uses [Cloudflare's Miniflare](https://developers.cloudflare.com/workers/testing/miniflare/) to host infrastructure and services locally.  

The codebase is structured following Domain-Driven Design principles and employs a Hexagonal Architecture style.  

## Live Demonstration  

This project is hosted on Cloudflare and can be accessed at [https://backoffice-elm.software-craftsmen.dev/](https://backoffice-elm.software-craftsmen.dev/).  

## Implementation Details  

Key implementation aspects include:  

1. **Backend Services**  
   Backend services are initialized using Elm's `Platform.worker(..)` function, without requiring a DOM component to mount. Requests are sent to the Elm application through a port. The JavaScript bootstrap code is located in [worker.js](js/worker.js).  

2. **Cloudflare Runtime API Communication**  
   Communication with Cloudflare runtime APIs is achieved by patching the source code to replace function bodies in JavaScript. See [patches.js](js/patches.js). The Elm code returns `Task x y` to represent asynchronous functions. While this approach is not idiomatic Elm, it allows requests and responses to be bound together effectively.  

3. **Use Cases**  
   [Use cases](src/BoundedContext/Scheduling/Usecase/) represent individual flows. A use case is triggered by sending a Command and results in a `CommandResult`. I/O dependencies, specific to each use case, are provided as arguments during initialization.  

4. **State Modeling**  
   Use case states are modeled as state machines. The state transitions via the `next` function, and termination occurs when the process completes with either an error or a success result.  

5. **Durable Object Repositories**  
   Durable Object repositories are implemented in JavaScript and interface with Elm through [Cloudflare's RPC methods](https://developers.cloudflare.com/durable-objects/best-practices/create-durable-object-stubs-and-send-requests/#invoke-rpc-methods).  

6. **Optimistic Concurrency**  
   Data stored in Durable Objects is wrapped in a `Transaction a` type to enable optimistic concurrency. While Durable Objects enforce a single-writer principle, this principle can be broken when accessed from a standard worker. The `Transaction a` type includes a numeric version to detect and reject concurrent writes, enabling transactional-like behavior. The process involves:  
   - Reading from a Durable Object using the `begin` method and capturing its version.  
   - Writing to the Durable Object using the `commit` method, ensuring the version matches the expected value.  
     If a concurrent transaction overwrites the data, a conflict error is returned.  

7. **Patterns for Domain Modeling**  
   The codebase utilizes [smart constructors](https://wiki.haskell.org/index.php?title=Smart_constructors) and the [Parse, Don’t Validate](https://lexi-lambda.github.io/blog/2019/11/05/parse-don-t-validate/) pattern to make illegal states unrepresentable.  

## Installation  

To compile and run the source code, ensure the following are installed:  
- Elm  
- Node.js (with npm)  
- Make  

See the [Makefile](Makefile) exposes `build@scheduling-api`, `build@scheduling-dashboard-projection` and `build@backoffice` tasks to compile (transpile) the sources. 

## Run Locally  

### Backend  
To run the backend locally, execute:  

```shell
make serve@backend
```  

This command installs the required dependencies, compiles the sources, and starts Miniflare.  

### Frontend  
To run the frontend locally, execute:  

```shell
make serve@frontend
```  

The console output will display the HTTP address where the frontend is running.  

## Other  

The Makefile includes additional tasks, such as deployment operations. Some tasks require additional parameters, marked with `TODO`. Ensure these parameters are properly configured before running the tasks.  
