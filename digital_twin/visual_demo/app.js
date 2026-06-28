const state = {
  running: false,
  packML: "IDLE",
  mode: "AUTO",
  alarm: "No alarm",
  alarmActive: false,
  speedMps: 0.55,
  elapsed: 0,
  nextSpawn: 0.8,
  packageId: 1,
  packages: [],
  total: 0,
  laneA: 0,
  laneB: 0,
  reject: 0,
  jams: 0,
  events: [],
  scenario: "normal",
  recipe: 1,
  jamLatched: false,
  lastTimestamp: performance.now(),
};

const routePatterns = {
  1: ["A", "A", "B", "A", "R"],
  2: ["B", "A", "B", "B", "R"],
  3: ["A", "B", "R", "R", "A"],
};

const sensors = [
  { id: "pe1", x: 0.08 },
  { id: "pe2", x: 0.28 },
  { id: "pe3", x: 0.52 },
  { id: "pe6", x: 0.92 },
];

function addEvent(kind, message) {
  const stamp = new Date().toLocaleTimeString();
  state.events.unshift({ stamp, kind, message });
  state.events = state.events.slice(0, 12);
}

function startCell() {
  if (state.running) return;
  state.running = true;
  state.packML = "EXECUTE";
  state.alarm = "No alarm";
  state.alarmActive = false;
  addEvent("STATE", "Cell entered EXECUTE");
}

function stopCell() {
  state.running = false;
  state.packML = "STOPPED";
  addEvent("STATE", "Stop command accepted");
}

function resetJam() {
  if (!state.jamLatched) {
    addEvent("RECOVERY", "Reset requested with no active jam");
    return;
  }
  state.jamLatched = false;
  state.alarmActive = false;
  state.alarm = "No alarm";
  state.packML = state.running ? "EXECUTE" : "STOPPED";
  state.packages = state.packages.filter((pkg) => !pkg.jammed);
  addEvent("RECOVERY", "Jam cleared and station unheld");
}

function spawnPackage() {
  const pattern = routePatterns[state.recipe] || routePatterns[1];
  let route = pattern[(state.packageId - 1) % pattern.length];
  let barcode = `PKG-${route}-${String(state.packageId).padStart(3, "0")}`;
  if (state.scenario === "bad_scan" && state.packageId % 3 === 0) {
    route = "R";
    barcode = "BAD-SCAN";
  }
  state.packages.push({
    id: state.packageId,
    x: -0.02,
    route,
    barcode,
    diverted: false,
    exitAge: 0,
    scanned: false,
    jammed: false,
  });
  addEvent("ROUTE", `Package ${state.packageId} registered as ${route}`);
  state.packageId += 1;
}

function update(dt) {
  state.elapsed += dt;
  if (state.running && !state.jamLatched) {
    state.nextSpawn -= dt;
    if (state.nextSpawn <= 0) {
      spawnPackage();
      state.nextSpawn = state.scenario === "slow_throughput" ? 5.8 : 2.6;
    }
  }

  const speed = state.scenario === "slow_throughput" ? 0.25 : state.speedMps;
  for (const pkg of state.packages) {
    if (!state.running || state.jamLatched) continue;

    if (state.scenario === "jam_pe3" && !state.jamLatched && pkg.x >= 0.52 && pkg.x < 0.58) {
      pkg.jammed = true;
      state.jamLatched = true;
      state.running = false;
      state.packML = "HELD";
      state.alarmActive = true;
      state.alarm = "Jam PE3";
      state.jams += 1;
      addEvent("ALARM", `Package ${pkg.id} jam detected at PE3`);
      continue;
    }

    if (!pkg.diverted) {
      pkg.x += speed * dt / 4.2;
      if (!pkg.scanned && pkg.x >= 0.28) {
        pkg.scanned = true;
        addEvent("SCAN", `${pkg.barcode} read at scanner`);
      }
      if (pkg.route === "A" && pkg.x >= 0.52) {
        pkg.diverted = true;
        pkg.exitAge = 0;
        addEvent("ROUTE", `Package ${pkg.id} diverted to Lane A`);
      } else if (pkg.route === "B" && pkg.x >= 0.74) {
        pkg.diverted = true;
        pkg.exitAge = 0;
        addEvent("ROUTE", `Package ${pkg.id} diverted to Lane B`);
      } else if (pkg.route === "R" && pkg.x >= 0.92) {
        pkg.diverted = true;
        pkg.exitAge = 0;
        pkg.rejecting = true;
        addEvent("ROUTE", `Package ${pkg.id} routed to reject`);
      }
    } else {
      pkg.exitAge += dt;
      if (pkg.route === "A") pkg.y = Math.min(1, pkg.exitAge / 1.0);
      if (pkg.route === "B") pkg.y = Math.min(1, pkg.exitAge / 1.0);
      if (pkg.route === "R") pkg.y = Math.min(1, pkg.exitAge / 1.0);
    }
  }

  const completed = [];
  state.packages = state.packages.filter((pkg) => {
    if (pkg.diverted && pkg.exitAge >= 1.05) {
      completed.push(pkg);
      return false;
    }
    return pkg.x <= 1.08 || pkg.jammed || pkg.diverted;
  });
  for (const pkg of completed) {
    state.total += 1;
    if (pkg.route === "A") state.laneA += 1;
    if (pkg.route === "B") state.laneB += 1;
    if (pkg.route === "R") state.reject += 1;
  }
}

function render() {
  document.getElementById("modePill").textContent = state.mode;
  document.getElementById("statePill").textContent = state.packML;
  const alarmPill = document.getElementById("alarmPill");
  alarmPill.textContent = state.alarm;
  alarmPill.className = `pill ${state.alarmActive ? "alarm" : "ok"}`;

  document.getElementById("totalCount").textContent = state.total;
  document.getElementById("laneACount").textContent = state.laneA;
  document.getElementById("laneBCount").textContent = state.laneB;
  document.getElementById("rejectCount").textContent = state.reject;
  document.getElementById("jamCount").textContent = state.jams;
  const minutes = Math.max(state.elapsed / 60, 0.01);
  document.getElementById("throughput").textContent = `${(state.total / minutes).toFixed(1)} ppm`;

  for (const sensor of sensors) {
    const active = state.packages.some((pkg) => Math.abs(pkg.x - sensor.x) < 0.035);
    document.getElementById(sensor.id).classList.toggle("active", active);
  }

  document.getElementById("div1").classList.toggle("extended", state.packages.some((pkg) => pkg.route === "A" && pkg.x > 0.49 && pkg.x < 0.58));
  document.getElementById("div2").classList.toggle("extended", state.packages.some((pkg) => pkg.route === "B" && pkg.x > 0.71 && pkg.x < 0.8));

  const layer = document.getElementById("packagesLayer");
  layer.innerHTML = state.packages.map((pkg) => {
    const left = Math.max(0, Math.min(100, pkg.x * 100));
    let top = 34;
    if (pkg.diverted && pkg.route === "A") top = 34 - (pkg.y || 0) * 145;
    if (pkg.diverted && pkg.route === "B") top = 34 - (pkg.y || 0) * 145;
    if (pkg.diverted && pkg.route === "R") top = 34 + (pkg.y || 0) * 140;
    const rejectClass = pkg.route === "R" ? " reject" : "";
    return `<div class="pkg${rejectClass}" style="left:${left}%; top:${top}px">${pkg.id}</div>`;
  }).join("");

  document.getElementById("signalList").innerHTML = [
    ["ControlState.CurrentState", state.packML],
    ["DeviceSet.Conveyor_1.SpeedFeedback", `${state.running ? state.speedMps.toFixed(2) : "0.00"} m/s`],
    ["Alarms.GeneralJamAlarm", state.alarmActive],
    ["KPIs.ThroughputTotal", state.total],
    ["KPIs.TotalJams", state.jams],
    ["Recipes.ActiveRecipeID", state.recipe],
  ].map(([name, value]) => `<dt>${name}</dt><dd>${value}</dd>`).join("");

  document.getElementById("eventList").innerHTML = state.events
    .map((event) => `<li><strong>${event.stamp} ${event.kind}</strong><br>${event.message}</li>`)
    .join("");
}

function tick(now) {
  const dt = Math.min(0.1, (now - state.lastTimestamp) / 1000);
  state.lastTimestamp = now;
  update(dt);
  render();
  requestAnimationFrame(tick);
}

document.getElementById("startBtn").addEventListener("click", startCell);
document.getElementById("stopBtn").addEventListener("click", stopCell);
document.getElementById("resetBtn").addEventListener("click", resetJam);
document.getElementById("scenarioSelect").addEventListener("change", (event) => {
  state.scenario = event.target.value;
  state.packages = [];
  state.jamLatched = false;
  state.alarmActive = false;
  state.alarm = "No alarm";
  state.running = false;
  state.packML = "IDLE";
  addEvent("SCENARIO", `Scenario set to ${event.target.selectedOptions[0].textContent}`);
});
document.getElementById("recipeSelect").addEventListener("change", (event) => {
  state.recipe = Number(event.target.value);
  addEvent("RECIPE", `Recipe ${state.recipe} loaded`);
});

addEvent("STATE", "Visual twin ready");
requestAnimationFrame(tick);
