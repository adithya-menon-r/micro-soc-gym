---
title: Micro-SOC Gym
sdk: docker
app_port: 7860
---

# Micro-SOC Gym Environment

A Reinforcement Learning Environment simulating a Security Operations Center (SOC) triage engine.
Built for the Meta × Hugging Face × PyTorch OpenEnv Hackathon 2026.

---

## 1. Executive Summary

Micro-SOC Gym models a high-stakes, real-time Security Operations Center environment designed for Reinforcement Learning (RL) agents. Rather than relying on rigid predefined simulators, the environment utilizes an active monolithic Docker container. RL agents are tasked with ingesting live `nginx` and `auth` logs to identify malicious network behavior and executing targeted remedial actions without disrupting legitimate infrastructure.

## 2. Simulated Threat Scenarios

The environment programmatically transitions through tiered security incidents during its lifecycle. Agents must adapt their decision-making logic recursively as the threat models increase in complexity.

### Scenario 1: Volumetric Network Scanning
- **Description:** A primary Host emits a high frequency of `HTTP 404` errors directed at non-existent administrative endpoints.
- **Agent Objective:** Parse the target log stream, identify the offending IP, and apply an application-layer block.
- **Evaluation Criteria:** Reward +1.0 for correctly deploying `block_ip(IP)`.

### Scenario 2: Identity Compromise & Subnet Decoys
- **Description:** Methodical SSH credential stuffing attempts are isolated within `auth.log`.
- **Agent Objective:** Deploy a surgical IP block against the attacking node.
- **Evaluation Criteria:** Legitimate administrative traffic (e.g., IP `10.0.0.100`) is mixed within the log stream. Agents utilizing broad subnet bans will inadvertently block administrative access, resulting in a critical incident failure (Reward 0.0).

### Scenario 3: Active Command and Control (C2) Remediation
- **Description:** A persistent threat has established a PHP backdoor within the application root and is executing Base64-encoded command sequences.
- **Agent Objective:** Conduct a multi-stage kill-chain operation to remediate the compromised asset.
- **Evaluation Criteria:** The agent must sequentially execute `kill_process(PID)` and `delete_file(FILE)` to safely terminate the session.

---

## 3. Architecture & Interface Specifications

### 3.1 Observation Space
The environment exposes state via the `MicroSocGymObservation` JSON payload:
- `logs` (String): A realtime 50-line tail buffer of the relevant target log.
- `reward` (Float): Current environment score bound between `0.0` and `1.0`.
- `done` (Boolean): Indicates terminal state or critical system failure.
- `success` (Boolean): Confirms successful neutralization of the active threat.
- `info` (String): Contextual metadata and grading feedback.

### 3.2 Action Space
Agents interface with the infrastructure via the `MicroSocGymAction` definitions:
- `block_ip(ip_address: str)`: Commits the specified node to the Nginx blocklist.
- `delete_file(file_path: str)`: Removes unverified binaries from the host path.
- `kill_process(pid: int)`: Transmits a SIGKILL signal to the identified rogue process.

### 3.3 Security & Systems Engineering Constraints
Due to the unprivileged container constraints imposed by standard Hugging Face Spaces (preventing kernel-level `iptables` rules), this environment handles infrastructure networking by leveraging `supervisord` overhead. Nginx processes are controlled in tandem with dummy attacker bash scripts to generate functional mock systems via pseudo-firewall loopbacks (by writing dynamically to `/etc/nginx/blocklist.conf`).

---

## 4. Evaluation and Baseline Scoring

To benchmark internal models, ensure the required network packages are present and execute the validation protocols.

| Task Category | Difficulty | Evaluation Result | Diagnostic Score |
| :--- | :--- | :--- | :--- |
| **Noisy Scanner** | Basic | TBD | TBD |
| **Stealth Brute Force** | Intermediate | TBD | TBD |
| **Active Webshell** | Advanced | TBD | TBD |
| **Global Benchmark** | | | **TBD / 1.00** |

*(Note: Baseline scores are generated using the `inference.py` runtime script powered by the `Qwen/Qwen2.5-72B-Instruct` model through the Hugging Face Inference API.)*

---

## 5. Setup and Operational Directives

### 5.1 Local Container Orchestration
The primary environment operates as a self-contained monolith.
```bash
# 1. Compile the primary container asset
docker build -t micro-soc-gym .

# 2. Deploy locally observing port 7860 standard constraints
docker run -p 7860:7860 micro-soc-gym
```
Access the environment telemetry safely via the GUI accessible at `http://localhost:7860/`.

### 5.2 Agent Execution Protocol
To initiate the AI agent response simulation:
```powershell
# 1. Initialize local Python virtual environment dependencies
python -m venv .venv
.\.venv\Scripts\activate
pip install -r requirements.txt

# 2. Assign environment variables mapping to valid access credentials
$env:HF_TOKEN="<your_secure_hf_token>"

# 3. Trigger standard inference
python inference.py
```

---

## 6. Project Structure

```text
micro_soc_gym/
├── .dockerignore                     # Docker build optimization exclusions
├── Dockerfile                        # Environment runtime manifest
├── openenv.yaml                      # OpenEnv space configuration file
├── requirements.txt                  # Consolidated unified Python dependency matrix
├── supervisord.conf                  # Core process configuration and task controller
├── inference.py                      # Automated LLM baseline execution script
├── client.py                         # HTTP synchronous agent connection wrapper
├── models.py                         # Application-layer Pydantic object schemas
├── nginx-default                     # Nginx server routing and blocklist definitions
│
├── scripts/                          # Simulated Threat Injectors
│   ├── easy_attack.sh                # Volumetric HTTP 404 flooding script
│   ├── medium_attack.sh              # Sequential SSH brute-force simulator
│   └── hard_attack.sh                # PHP remote code execution (RCE) setup utility
│
└── server/                           # OpenEnv Backend Services
    ├── app.py                        # FastAPI endpoints and Gradio telemetry dashboard
    ├── micro_soc_gym_environment.py  # Primary orchestration, environment state, and grader logic
    └── __init__.py                   # Core service exports
```
