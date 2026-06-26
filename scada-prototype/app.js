const modeNames = ["MANUAL", "AUTO", "MAINTENANCE"];
const stateNames = {
  0: "STOPPED",
  1: "STARTING",
  2: "EXECUTE",
  3: "SUSPENDED",
  4: "HOLDING",
  5: "HELD",
  6: "UNHOLDING",
  7: "STOPPING",
  8: "ABORTED",
  9: "IDLE",
  10: "RESETTING",
};

const tags = {
  HMI_Cell_Mode: { type: "Int32", node: "ControlState.CurrentMode", value: 1 },
  HMI_Cell_State: { type: "Int32", node: "ControlState.CurrentState", value: 9 },
  HMI_Cell_PermissivesOK: { type: "Boolean", node: "ControlState.PermissivesOK", value: true },
  HMI_Cell_Heartbeat: { type: "UInt16", node: "ControlState.Heartbeat", value: 1240 },
  HMI_HistorianHealthy: { type: "Boolean", node: "PLCIntegration.HistorianHealthy", value: true },
  HMI_Conveyor1_Running: { type: "Boolean", node: "DeviceSet.Conveyor_1.IsRunning", value: false },
  HMI_Conveyor1_SpeedSetpoint: { type: "Double", node: "DeviceSet.Conveyor_1.SpeedSetpoint", value: 0.5, unit: "m/s" },
  HMI_Conveyor1_SpeedFeedback: { type: "Double", node: "DeviceSet.Conveyor_1.SpeedFeedback", value: 0.0, unit: "m/s" },
  HMI_Conveyor1_VFDCurrent: { type: "Double", node: "DeviceSet.Conveyor_1.VFD_Current", value: 0.8, unit: "A" },
  HMI_Conveyor1_Faulted: { type: "Boolean", node: "DeviceSet.Conveyor_1.Faulted", value: false },
  HMI_PE1_Blocked: { type: "Boolean", node: "DeviceSet.Conveyor_1.PE1_Blocked", value: false },
  HMI_PE2_Blocked: { type: "Boolean", node: "DeviceSet.Conveyor_1.PE2_Blocked", value: false },
  HMI_PE3_Blocked: { type: "Boolean", node: "DeviceSet.Conveyor_1.PE3_Blocked", value: false },
  HMI_Scanner1_LastBarcode: { type: "String", node: "DeviceSet.Scanner_1.LastReadBarcode", value: "PKG-A-1042" },
  HMI_Scanner1_ReadSuccess: { type: "Boolean", node: "DeviceSet.Scanner_1.ReadSuccess", value: true },
  HMI_Diverter1_Home: { type: "Boolean", node: "DeviceSet.Diverter_1.Home", value: true },
  HMI_Diverter1_Work: { type: "Boolean", node: "DeviceSet.Diverter_1.Work", value: false },
  HMI_Diverter1_Verify: { type: "Boolean", node: "DeviceSet.Diverter_1.PE_Verify", value: false },
  HMI_Diverter1_Faulted: { type: "Boolean", node: "DeviceSet.Diverter_1.Faulted", value: false },
  HMI_Diverter2_Home: { type: "Boolean", node: "DeviceSet.Diverter_2.Home", value: true },
  HMI_Diverter2_Work: { type: "Boolean", node: "DeviceSet.Diverter_2.Work", value: false },
  HMI_Diverter2_Verify: { type: "Boolean", node: "DeviceSet.Diverter_2.PE_Verify", value: false },
  HMI_Diverter2_Faulted: { type: "Boolean", node: "DeviceSet.Diverter_2.Faulted", value: false },
  HMI_SubscribeEnable: { type: "Boolean", node: "PLCIntegration.SubscribeEnable", value: true },
  HMI_CollectorHeartbeat: { type: "Boolean", node: "PLCIntegration.CollectorHeartbeat", value: false },
  ALM_AnyActive: { type: "Boolean", node: "Alarms.AnyActive", value: false },
  ALM_AnyUnacked: { type: "Boolean", node: "Alarms.AnyUnacked", value: false },
  ALM_ActiveCode: { type: "UInt16", node: "Alarms.ActiveCode", value: 0 },
  ALM_Severity: { type: "UInt16", node: "Alarms.Severity", value: 0 },
  ALM_ActiveMessage: { type: "String", node: "Alarms.ActiveMessage", value: "No active alarms" },
  ALM_GeneralJamAlarm: { type: "Boolean", node: "Alarms.GeneralJamAlarm", value: false },
  KPI_Throughput_Total: { type: "UInt32", node: "KPIs.ThroughputTotal", value: 1420 },
  KPI_Throughput_LaneA: { type: "UInt32", node: "KPIs.ThroughputLaneA", value: 820 },
  KPI_Throughput_LaneB: { type: "UInt32", node: "KPIs.ThroughputLaneB", value: 480 },
  KPI_Throughput_Reject: { type: "UInt32", node: "KPIs.ThroughputReject", value: 120 },
  KPI_Throughput_PerMinute: { type: "Double", node: "/kpis.throughput_per_min", value: 34.2 },
  KPI_TotalJams: { type: "UInt16", node: "KPIs.TotalJams", value: 2 },
  KPI_Availability: { type: "Double", node: "KPIs.Availability", value: 0.94, unit: "" },
  KPI_AverageCycleTime_s: { type: "Double", node: "/kpis.average_cycle_time_s", value: 1.8, unit: "s" },
  KPI_MeanTimeBetweenJams_s: { type: "Double", node: "/kpis.mean_time_between_jams_s", value: 1620, unit: "s" },
  KPI_OEE_Percent: { type: "Double", node: "KPIs.OEE", value: 88.5, unit: "%" },
  KPI_Window_s: { type: "Double", node: "/kpis.window_s", value: 300, unit: "s" },
  CMD_MaintenanceKey: { type: "Boolean", node: "Maintenance.MaintenanceKey", value: false },
  CMD_ManualJogForward: { type: "Boolean", node: "Maintenance.ManualJogForward", value: false },
  CMD_ManualJogSpeed: { type: "Double", node: "Maintenance.ManualJogSpeed", value: 0.2, unit: "m/s" },
  CMD_Recipe_TargetSpeed: { type: "Double", node: "Recipes.TargetSpeed", value: 0.5, unit: "m/s" },
  HMI_Recipe_ActiveID: { type: "UInt16", node: "Recipes.ActiveRecipeID", value: 1 },
  HMI_Recipe_ActiveName: { type: "String", node: "Recipes.ActiveRecipeName", value: "Standard Boxes" },
  EVT_LastSequence: { type: "UInt32", node: "EventTimeline.LastSequence", value: 104 },
  EVT_LastMessage: { type: "String", node: "EventTimeline.LastMessage", value: "No active alarms" },
  EVT_LastSeverity: { type: "UInt16", node: "EventTimeline.LastSeverity", value: 0 },
};

const recipes = [
  { id: 1, name: "Standard Boxes", speed: 0.5, pattern: "A/B balanced" },
  { id: 2, name: "High Speed Sort", speed: 0.9, pattern: "Lane A priority" },
  { id: 3, name: "Reject Audit", speed: 0.35, pattern: "Reject verification" },
];

const events = [
  { time: "09:41:18", tag: "EVT_LastMessage", message: "Recipe Standard Boxes loaded", severity: 100 },
  { time: "09:44:02", tag: "ALM_GeneralJamAlarm", message: "Package jam cleared", severity: 400 },
  { time: "09:52:55", tag: "ALM_ActiveMessage", message: "No active alarms", severity: 0 },
];

function formatTag(tagName) {
  const tag = tags[tagName];
  if (!tag) return "-";
  if (tagName === "HMI_Cell_Mode") return modeNames[tag.value] || `Mode ${tag.value}`;
  if (tagName === "HMI_Cell_State") return stateNames[tag.value] || `State ${tag.value}`;
  if (tag.type === "Boolean") return tag.value ? "TRUE" : "FALSE";
  return `${tag.value}${tag.unit ? ` ${tag.unit}` : ""}`;
}

function setTag(tagName, value) {
  if (!tags[tagName]) return;
  tags[tagName].value = value;
}

function renderTags() {
  document.querySelectorAll("[data-tag]").forEach((element) => {
    element.textContent = formatTag(element.dataset.tag);
  });

  document.querySelectorAll("[data-indicator]").forEach((element) => {
    const tagName = element.dataset.indicator;
    const active = Boolean(tags[tagName]?.value);
    element.classList.toggle("active", active);
    element.classList.toggle("alarm", tagName.startsWith("ALM_") && active);
  });

  document.getElementById("header-mode").textContent = `Mode ${formatTag("HMI_Cell_Mode")}`;
  document.getElementById("header-state").textContent = `State ${formatTag("HMI_Cell_State")}`;
  document.getElementById("header-permissives").textContent = `Permissives ${formatTag("HMI_Cell_PermissivesOK")}`;
  document.getElementById("header-historian").textContent = `Historian ${formatTag("HMI_HistorianHealthy")}`;
  document.getElementById("header-alarm").textContent = `Alarm ${formatTag("ALM_AnyActive")}`;

  renderRecoverySteps();
  renderRecipeTable();

  const alarmTable = document.getElementById("alarm-table");
  alarmTable.innerHTML = events.map((event) => `
    <tr>
      <td>${event.time}</td>
      <td>${event.tag}</td>
      <td>${event.message}</td>
      <td>${event.severity}</td>
    </tr>
  `).join("");
}

function renderRecoverySteps() {
  const stopped = tags.HMI_Cell_State.value === 0 || tags.HMI_Cell_State.value === 5;
  const sensorsClear = !tags.HMI_PE1_Blocked.value && !tags.HMI_PE2_Blocked.value && !tags.HMI_PE3_Blocked.value;
  const divertersHome = tags.HMI_Diverter1_Home.value && tags.HMI_Diverter2_Home.value;
  const resetReady = sensorsClear && divertersHome && !tags.ALM_GeneralJamAlarm.value;
  const restartReady = resetReady && tags.HMI_Cell_PermissivesOK.value;
  const states = { stop: stopped, clear: sensorsClear, home: divertersHome, reset: resetReady, restart: restartReady };
  document.querySelectorAll("[data-step]").forEach((step) => {
    step.classList.toggle("complete", Boolean(states[step.dataset.step]));
  });
}

function renderRecipeTable() {
  const table = document.getElementById("recipe-table");
  if (!table) return;
  table.innerHTML = recipes.map((recipe) => `
    <tr class="${recipe.id === tags.HMI_Recipe_ActiveID.value ? "selected" : ""}">
      <td>${recipe.id}</td>
      <td>${recipe.name}</td>
      <td>${recipe.speed.toFixed(2)} m/s</td>
      <td>${recipe.pattern}</td>
    </tr>
  `).join("");
}

function handleCommand(command) {
  const now = new Date().toLocaleTimeString();
  if (command === "CMD_StartCell") {
    setTag("HMI_Cell_State", 2);
    setTag("HMI_Conveyor1_Running", true);
    setTag("HMI_Conveyor1_SpeedFeedback", tags.HMI_Conveyor1_SpeedSetpoint.value);
    events.unshift({ time: now, tag: command, message: "Start command accepted", severity: 100 });
  }
  if (command === "CMD_StopCell") {
    setTag("HMI_Cell_State", 0);
    setTag("HMI_Conveyor1_Running", false);
    setTag("HMI_Conveyor1_SpeedFeedback", 0.0);
    events.unshift({ time: now, tag: command, message: "Stop command accepted", severity: 100 });
  }
  if (command === "CMD_AlarmAcknowledge") {
    setTag("ALM_AnyUnacked", false);
    events.unshift({ time: now, tag: command, message: "Alarm acknowledged", severity: 200 });
  }
  if (command === "CMD_ResetJam") {
    setTag("ALM_GeneralJamAlarm", false);
    setTag("ALM_AnyActive", false);
    setTag("ALM_ActiveCode", 0);
    setTag("ALM_Severity", 0);
    setTag("ALM_ActiveMessage", "No active alarms");
    setTag("EVT_LastSequence", tags.EVT_LastSequence.value + 1);
    setTag("EVT_LastMessage", "Jam reset command accepted");
    setTag("EVT_LastSeverity", 200);
    events.unshift({ time: now, tag: command, message: "Jam reset command accepted", severity: 200 });
  }
  if (command === "CMD_ManualJogForward") {
    setTag("CMD_ManualJogForward", true);
    setTag("HMI_Conveyor1_Running", true);
    setTag("HMI_Conveyor1_SpeedFeedback", 0.2);
    events.unshift({ time: now, tag: command, message: "Maintenance jog simulated", severity: 100 });
  }
  if (command === "CMD_Scanner1_Trigger") {
    setTag("HMI_Scanner1_LastBarcode", `PKG-${Math.floor(Math.random() * 9000) + 1000}`);
    setTag("HMI_Scanner1_ReadSuccess", true);
    events.unshift({ time: now, tag: command, message: "Scanner trigger simulated", severity: 100 });
  }
  if (command === "CMD_Diverter1_Extend") {
    setTag("HMI_Diverter1_Home", false);
    setTag("HMI_Diverter1_Work", true);
    events.unshift({ time: now, tag: command, message: "Diverter 1 extend simulated", severity: 100 });
  }
  if (command === "CMD_Diverter2_Extend") {
    setTag("HMI_Diverter2_Home", false);
    setTag("HMI_Diverter2_Work", true);
    events.unshift({ time: now, tag: command, message: "Diverter 2 extend simulated", severity: 100 });
  }
  if (command === "CMD_ResetCounters") {
    setTag("KPI_Throughput_Total", 0);
    setTag("KPI_Throughput_LaneA", 0);
    setTag("KPI_Throughput_LaneB", 0);
    setTag("KPI_Throughput_Reject", 0);
    events.unshift({ time: now, tag: command, message: "KPI counters reset in mock model", severity: 200 });
  }
  if (command === "CMD_MaintenanceKey") {
    setTag("CMD_MaintenanceKey", !tags.CMD_MaintenanceKey.value);
    setTag("HMI_Cell_Mode", tags.CMD_MaintenanceKey.value ? 2 : 1);
    events.unshift({ time: now, tag: command, message: "Maintenance key toggled in mock model", severity: 100 });
  }
  if (command === "CMD_CollectorHeartbeat") {
    setTag("HMI_CollectorHeartbeat", !tags.HMI_CollectorHeartbeat.value);
    events.unshift({ time: now, tag: command, message: "Collector heartbeat toggled", severity: 100 });
  }
  if (command === "CMD_LoadRecipe") {
    const currentIndex = recipes.findIndex((recipe) => recipe.id === tags.HMI_Recipe_ActiveID.value);
    const next = recipes[(currentIndex + 1) % recipes.length];
    setTag("HMI_Recipe_ActiveID", next.id);
    setTag("HMI_Recipe_ActiveName", next.name);
    setTag("CMD_Recipe_TargetSpeed", next.speed);
    setTag("HMI_Conveyor1_SpeedSetpoint", next.speed);
    events.unshift({ time: now, tag: command, message: `Recipe ${next.name} loaded`, severity: 100 });
  }
  renderTags();
}

document.querySelectorAll(".tab").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".tab").forEach((tab) => tab.classList.remove("is-active"));
    document.querySelectorAll(".screen").forEach((screen) => screen.classList.remove("is-active"));
    button.classList.add("is-active");
    document.getElementById(button.dataset.screen).classList.add("is-active");
  });
});

document.querySelectorAll("[data-command]").forEach((button) => {
  button.addEventListener("click", () => handleCommand(button.dataset.command));
});

setInterval(() => {
  setTag("HMI_Cell_Heartbeat", (tags.HMI_Cell_Heartbeat.value + 1) % 65535);
  renderTags();
}, 1000);

renderTags();
