const fs = require('fs');

function $author$project$Prelude$Time$isSupportedZoneNameFFI(zone) {
  return Intl.supportedValuesOf('timeZone').includes(zone);
}

function $author$project$Prelude$Time$formatPosixAsRfc3339FFI(zone) {
  return function(posix) {
    const format = new Intl.DateTimeFormat(
      "en-US", 
      {
        year: "numeric",
        month: "2-digit",
        day: "2-digit",
        hour: "2-digit",
        hour12: false,
        minute: "2-digit",
        second: "2-digit",
        timeZone: zone,
        timeZoneName: "longOffset"
      }
    );
    
    const date = format
      .formatToParts(new Date(posix))
      .reduce((date, part) => { date[part.type] = part.value; return date }, {});
    
    return `${date.year}-${date.month}-${date.day}T${date.hour}:${date.minute}:${date.second}${date.timeZoneName.replace("GMT", "") || "Z"}`;  
  }
}

function $author$project$Cloudflare$Worker$DurableObject$getFFI(options) {
  return _Scheduler_binding(function(next) {
    try {
      const { binding, partition, key } = options;
      const namespace = globalThis.env[binding];
      const id = namespace.idFromName(partition);
      const stub = namespace.get(id);
      
      stub.get(key)
        .then(value => next(_Scheduler_succeed(value)))
        .catch(reason => next(_Scheduler_fail(reason.toString())));
    } 
    catch(exception) {
      next(_Scheduler_fail(exception.toString()));
    }
  });
}

function $author$project$Cloudflare$Worker$DurableObject$beginFFI(options) {
  return _Scheduler_binding(function(next) {
    try {
      const { binding, partition, key } = options;
      const namespace = globalThis.env[binding];
      const id = namespace.idFromName(partition);
      const stub = namespace.get(id);

      stub.begin(key)
        .then(value => next(_Scheduler_succeed(value)))
        .catch(reason => next(_Scheduler_fail(reason.toString())));
    } 
    catch(exception) {
      next(_Scheduler_fail(exception.toString()));
    }
  });
}

function $author$project$Cloudflare$Worker$DurableObject$commitFFI(options) {
  return _Scheduler_binding(function(next) {
    try {
      const { binding, partition, key, version, value } = options;
      const namespace = globalThis.env[binding];
      const id = namespace.idFromName(partition);
      const stub = namespace.get(id);

      stub.commit(key, version, value)
        .then(value => next(_Scheduler_succeed(value)))
        .catch(reason => next(_Scheduler_fail(reason.toString())));
    } 
    catch(exception) {
      next(_Scheduler_fail(exception.toString()));
    }
  });
}

function $author$project$Cloudflare$Worker$Queue$publishFFI(options) {
  return _Scheduler_binding(function(next) {
    try {
      const { binding, value } = options;
      const queue = globalThis.env[binding];

      queue.send(value)
        .then(value => next(_Scheduler_succeed(value)))
        .catch(reason => next(_Scheduler_fail(reason.toString())));
    } 
    catch(exception) {
      next(_Scheduler_fail(exception.toString()));
    }
  });
}

function $author$project$Cloudflare$Worker$R2$getFFI(options) {
  return _Scheduler_binding(function(next) {
    try {
      const { binding, key } = options;
      const bucket = globalThis.env[binding];

      bucket.get(key)
        .then(value => value ? value.json() : null)
        .then(value => next(_Scheduler_succeed(value)))
        .catch(reason => next(_Scheduler_fail(reason.toString())));
    } 
    catch(exception) {
      next(_Scheduler_fail(exception.toString()));
    }
  });
}

function $author$project$Cloudflare$Worker$R2$putFFI(options) {
  return _Scheduler_binding(function(next) {
    try {
      const { binding, metadata, key, value } = options;
      const bucket = globalThis.env[binding];

      bucket.put(key, value, metadata)
        .then(_ => next(_Scheduler_succeed({})))
        .catch(reason => next(_Scheduler_fail(reason.toString())));
    } 
    catch(exception) {
      next(_Scheduler_fail(exception.toString()));
    }
  });
}

// apply
const args = process.argv.slice(2);
if (args.length < 1) {
  console.log("no input file given");
  process.exit(-1);
}

function placeholder(name) {
  return new RegExp(`var ${name.replace(/\$/g, "\\$")} [^}]+}\\)?;`, "m"); 
}

const file = fs
  .readFileSync(args[0], { encoding: "utf8", flag: "r" })
  .replace(placeholder("$author$project$Prelude$Time$isSupportedZoneNameFFI"), $author$project$Prelude$Time$isSupportedZoneNameFFI.toString())
  .replace(placeholder("$author$project$Prelude$Time$formatPosixAsRfc3339FFI"), $author$project$Prelude$Time$formatPosixAsRfc3339FFI.toString())
  .replace(placeholder("$author$project$Cloudflare$Worker$DurableObject$getFFI"), $author$project$Cloudflare$Worker$DurableObject$getFFI.toString())
  .replace(placeholder("$author$project$Cloudflare$Worker$DurableObject$beginFFI"), $author$project$Cloudflare$Worker$DurableObject$beginFFI.toString())
  .replace(placeholder("$author$project$Cloudflare$Worker$DurableObject$commitFFI"), $author$project$Cloudflare$Worker$DurableObject$commitFFI.toString())
  .replace(placeholder("$author$project$Cloudflare$Worker$Queue$publishFFI"), $author$project$Cloudflare$Worker$Queue$publishFFI.toString())
  .replace(placeholder("$author$project$Cloudflare$Worker$R2$getFFI"), $author$project$Cloudflare$Worker$R2$getFFI.toString())
  .replace(placeholder("$author$project$Cloudflare$Worker$R2$putFFI"), $author$project$Cloudflare$Worker$R2$putFFI.toString())

fs.writeFileSync(args[0], file, { encoding: "utf8", flag: "w" });
