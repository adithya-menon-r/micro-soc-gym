---
title: Micro SOC Gym
sdk: docker
app_port: 7860
tags:
  - openenv
---

<div align="center">
  <img alt="Micro SOC Gym" src="https://img.shields.io/badge/OpenEnv-Compatible-blue.svg">
  <h1>Micro SOC Gym</h1>
  <p><strong>A Real time, Docker-Based Benchmark for RL Agents in Security Operations Center (SOC) Triage</strong></p>
  <p>Built for the <b>Meta × Hugging Face × PyTorch OpenEnv Hackathon 2026</b>.</p>
</div>

## Table of Contents

1. [Environment Description & Motivation](#1-environment-description--motivation)
2. [Observation & Action Space](#2-observation--action-space)
3. [Task Descriptions & Difficulty](#3-task-descriptions--difficulty)
4. [Inference & Results](#4-inference--results)
5. [Visual Workflow](#5-visual-workflow)
6. [Setup & Usage Instructions](#6-setup--usage-instructions)
7. [System Architecture](#7-system-architecture)
8. [Project Structure](#8-project-structure)
9. [Pre-Validation Results](#9-pre-validation-results)
10. [Team](#10-team)


## 1. Environment Description & Motivation

### Overview

**Micro SOC Gym** models a real time Security Operations Center (SOC) workload designed for evaluating Reinforcement Learning (RL) agents and LLMs. Rather than interacting with static datasets, agents interface with a real time, monolithic Docker container running production grade services.

The environment runs a FastAPI backend, simulated daemons (`nginx`, `sshd`), and orchestrated attacker scripts. Agents perform threat triage just like real analysts. It parses unstructured server log streams, maps threats and executes exact remediation actions.

### Motivation

In modern Security Operations Centers (SOCs), human analysts are generally overwhelmed by the volume of daily alerts. Because of this workload, anything that is not automated can slip through, leaving networks vulnerable. To safely automate this triage process, we need capable AI. This is why we chose to build Micro SOC Gym.

Standard LLM benchmarks test static multi-choice or simple generation capabilities. **Micro SOC Gym** forces the agent into a proactive system administration role. It challenges an agent's ability to:

1. Handle noisy data streams (identifying signal amidst decoy traffic).
2. Sequentially build and execute a remediation plan.
3. Understand precise constraints to avoid _False Positives_ - where overly aggressive actions can cause system failures.


## 2. Observation & Action Space

This environment is based on the standard **OpenEnv** HTTP JSON schema patterns defined through integrated Pydantic definitions.

### 2.1 Observation Space

State observations are fed continuously to the agent via the `MicroSocGymObservation` dictionary payload:

- **`reward` (Float)**: Immediate reinforcement mapping to the agent's recent action (-ve/0/+ve to help the agent understand the effect of the action).
- **`done` (Boolean)**: Marks terminal episode conditions (Success, Failure, or Max-Steps Exhaustion).
- **`success` (Boolean)**: Directly indicates if the active threat has been fully neutralized.
- **`info` (String)**: Grader feedback and human-readable context hints.

### 2.2 Action Space

Instead of simple directional movements, the agent manipulates an infrastructure API. The `MicroSocGymAction` requires specifying exactly one `tool` per step, categorized into Investigative and Remediation actions:

**Investigative Tools:**
1. **`read_access_log()`**
   - Reads the `/var/log/nginx/access.log` to parse web server traffic and identify anomalies or directory brute-forcing.
2. **`read_auth_log()`**
   - Reads the `/var/log/auth.log` to monitor system authentication events like SSH brute-force attempts.

**Remediation Tools:**
1. **`block_ip(ip_address: str)`**
   - Targets network ingress. Commits the rogue IP explicitly to the target's `/etc/nginx/blocklist.conf`.
2. **`kill_process(pid: int)`**
   - Transmits a system-level `SIGKILL` to forcefully terminate unauthorized command-and-control background processes.
3. **`delete_file(file_path: str)`**
   - Permanently deletes verified malware, webshells, or backdoor executable scripts from the host disk layer.

### 2.3 Reward and Penalty Logic

After running many episodes of each scenario and experimenting between different models we settled on this reward structure:

| Value | Name | Note |
| :---: | :--- | :--- |
| **0.50** | `CORRECT_ACTION_REWARD` | Given when the correct tool and correct target are selected (e.g., blocking the attacker IP, deleting the backdoor, or killing the malicious process). |
| **0.25** | `CORRECT_INVESTIGATIVE_DIRECTION_REWARD` | Partial reward for choosing the wrong logfile, but when the overall direction of investigation is correct. |
| **0.10** | `CORRECT_TOOL_WRONG_TARGET_REWARD` | Given when the tool choice is correct but the wrong target is provided (e.g., blocking the wrong IP or killing the wrong process PID). |
| **-0.20** | `PROCESS_KILL_FAIL_PENALTY` | Given when the process kill fails to execute (e.g., the process is already dead, not found, or could not be killed due to wrong PID). |
| **-0.25** | `ACTION_TO_STALL_PENALTY` | Given when the agent tries reading a different logfile after executing all remediation actions at least once. This was introduced because this is basically the agent stalling as it already has all the information it needs, and is executing the remediation actions incorrectly. |
| **-0.30** | `UNWARRANTED_ACTION_REPEAT_PENALTY` | Given when the agent unnecessarily repeats actions to game the system. This was introduced because the agent decided to read the same logs consecutively (or alternate `read_access_log`, `read_auth_log`, `read_access_log`... or re-blocking the same IP, or deleting a deleted file). This prevents the agent from exploiting such actions. |
| **-0.50** | `WRONG_TOOL_PENALTY` | Given when the agent chooses the wrong tool for the given scenario altogether. |
| **-0.75** | `WRONG_FILE_DELETION_PENALTY` | Given when the agent deletes the wrong file. Data is recoverable so it isn't completely fatal, but it is a severe mistake. |
| **-1.00** | `ADMIN_IP_BLOCK_PENALTY` | Given when the admin IP is mistakenly blocked. This is a FATAL penalty, as the system stability drops. |
| **-1.00** | `NON_INVESTIGATIVE_REMEDIATION_ACTION_PENALTY` | Given when the agent executes a remediation action without ever investigating the alert. This was introduced to penalise the agent because it will just try to guess through the whole episode without looking at logs, hence there is no point continuing. |


## 3. Task Descriptions & Difficulty

The environment runs each scenario via a round-robin rotation upon iteration (`/reset`). Agents must shift strategies and remediate based on the active threat.

| Difficulty | Name & Mechanics | Win Condition & Constraints |
| :---: | :--- | :--- |
| **Easy** | **Directory Brute Forcing**<br>A single IP is generating a massive amount of `HTTP 404` errors by brute forcing hidden admin pages (like `/admin` or `/wp-login.php`). | **Goal:** Find the malicious IP in `access.log` and call `block_ip(IP)`.<br>**Constraint:** None |
| **Medium** | **SSH Brute Force**<br>An attacker is brute forcing the server with failed SSH login attempts (visible in `auth.log`), but legitimate admin traffic is happening at the exact same time. | **Goal:** Identify the attacker's IP and call `block_ip(IP)`.<br>**Constraint:** High false-positive penalty. If the agent accidentally blocks the legitimate admin subnet, it triggers an immediate failure. |
| **Hard** | **Active C2 Backdoor**<br>An attacker IP has dropped a malicious file on the webserver and is actively sending base64-encoded commands to running processes. | **Goal:** Delete the backdoor, kill the malicious process and block the attacker IP.<br>**Constraint:** The agent must first remove the payload using `delete_file(FILE)` to prevent re-spawn of the malicious process. Then, it must kill the currently running mailcious process using `kill_process(PROCESS)` and then block the IP to prevent future payloads using `block_ip(IP)`. Doing any one or two will not stop the attacker. |


## 4. Inference & Results

The environment tests models across progressively harder scenarios. Below is an evaluation run using the `Qwen/Qwen2.5-72B-Instruct` model via our built in ReAct script (`inference.py`). 

The trace shows the agent successfully reading the environment state and calling the correct tools (`block_ip`, `delete_file`, `kill_process`). It achieves the maximum score of `0.99` in each scenario, resolving all the threats.

![Inference Results for Qwen 72B model](/media/inference.png)


## 5. Visual Workflow

To help visualise the environment, we built an interactive Gradio Dashboard which is available at `http://localhost:7860/` when the docker container is run. 

It lets you manually play the role of the responding agent. By reading the logs, triggering tools, and seeing how the environment scores your actions, you can easily understand the mechanics, constraints, and underlying reward logic the Agent has to learn.

https://github.com/user-attachments/assets/80c28b86-2f0f-4ad8-a383-8d50048c1a43

## 6. Setup & Usage Instructions

### 6.1 Running the Docker Container


```bash
# 1. Build the Docker Image
docker build -t micro-soc-gym .

# 2. Run the container
docker run -d -p 7860:7860 micro-soc-gym
```

**Note:** You can access the **Gradio Dashboard** at `http://localhost:7860/` for manual testing

### 6.2 Run the Agent against all Scenarios

```bash
# 1. Create a virtual environment and install dependencies
python -m venv .venv
source .venv/bin/activate  # (Windows: .\.venv\Scripts\activate)
pip install -r requirements.txt

# 2. Set Hugging Face Hub Credentials
export HF_TOKEN="<YOUR_HUGGING_FACE_TOKEN>"

# 3. Run the Inference Script
python inference.py
```


## 7. System Architecture

The codebase handles networking logic decoupled from kernel requirements via a supervised orchestration.

![Micro-SOC Gym system architecture](/media/architecture-diagram.png)

## 8. Project Structure

```text
micro_soc_gym/
├── .github/
│   └── workflows/
│       └── sync-to-hf.yml            # GitHub Actions workflow to sync repo to Hugging Face Space
├── media/                            # Static assets for documentation
├── scripts/                          # Subprocess Attack Generators
│   ├── easy_attack.sh                # Volumetric target traffic creator
│   ├── medium_attack.sh              # Mock SSH Brute-Force + Decoys
│   └── hard_attack.sh                # Webshell runtime process simulation
├── server/                           # OpenEnv Backend Services
│   ├── ui/                           # Gradio UI subpackage
│   │   ├── __init__.py               # Exports build_ui()
│   │   ├── components.py             # Pure HTML/SVG string generators
│   │   ├── handlers.py               # Gradio event handlers and episode state
│   │   └── layout.py                 # gr.Blocks layout assembly and component wiring
│   ├── __init__.py                   # Package initializer
│   ├── app.py                        # FastAPI endpoints and Gradio Telemetry Dashboard
│   ├── constants.py                  # Shared constant values and definitions
│   ├── micro_soc_gym_environment.py  # Builds the OpenEnv environment, Grading and Reward logic
│   └── utils.py                      # Reusable utilities and helper functions
├── __init__.py                       # Package initializer
├── client.py                         # Synchronous HTTP validation client
├── Dockerfile                        # Environment runtime manifest & OS provisions
├── inference.py                      # Automated LLM ReAct agent testing loop
├── models.py                         # Application-layer Pydantic schema exports
├── nginx-default                     # Nginx server configuration defaults and simulated routing
├── openenv.yaml                      # OpenEnv space requirement configuration
├── pyproject.toml                    # Python package configuration
├── README.md                         # Documentation
├── requirements.txt                  # Python dependencies
├── schema.json                       # Validation schema for standard OpenEnv JSON interactions
├── supervisord.conf                  # Daemon management orchestrator (Nginx, API, Attacks)
├── uv.lock                           # Locked dependency versions (uv)
└── validate-submission.sh            # Local strict validation helper script
```

## 9. Pre-Validation Results

Before deploying, we ran the environment through the given Pre-Validation Script. Everything passed, including the Docker build, Hugging Face Space liveness, and schema checks.

![OpenEnv Pre-Validation Success Output](/media/pre-validation.png)

<details>
<summary><b>View Raw Validation Logs</b></summary>

```text
========================================
  OpenEnv Submission Validator
========================================
[11:21:05] Repo:     /c/Users/hp859/Desktop/Meta X Hugging_Face Hacks/micro_soc_gym
[11:21:05] Ping URL: https://harinie4466-micro-soc-gym.hf.space

[11:21:05] Step 1/3: Pinging HF Space (https://harinie4466-micro-soc-gym.hf.space/reset) ...
[11:21:11] PASSED -- HF Space is live and responds to /reset
[11:21:11] Step 2/3: Running docker build ...
[11:21:11]   Found Dockerfile in /c/Users/hp859/Desktop/Meta X Hugging_Face Hacks/micro_soc_gym
[11:21:19] PASSED -- Docker build succeeded
[11:21:19] Step 3/3: Running openenv validate ...
[11:21:33] PASSED -- openenv validate passed
[11:21:33]   [OK] micro_soc_gym: Ready for multi-mode deployment

========================================
  All 3/3 checks passed!
  Your submission is ready to submit.
========================================

```

</details>

## 10. Team

| Name                   | GitHub ID                                               |
|------------------------|---------------------------------------------------------|
| Adithya Menon R        | [adithya-menon-r](https://github.com/adithya-menon-r)   |
| Harinie CB             | [harinie-4466](https://github.com/harinie-4466)         |
| Hari Prasath K         | [hariPrasathK-Dev](https://github.com/hariPrasathK-Dev) |
