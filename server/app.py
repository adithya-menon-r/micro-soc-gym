# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

from __future__ import annotations

try:
    from openenv.core.env_server.http_server import create_app
except Exception as exc:
    raise ImportError(
        "openenv-core is required. Run:  uv sync"
    ) from exc

import gradio as gr

from models import MicroSocGymAction, MicroSocGymObservation
from server.micro_soc_gym_environment import MicroSocGymEnvironment
from server.ui import build_ui


# Singleton environment shared between the OpenEnv HTTP API and the Gradio UI.
_env = MicroSocGymEnvironment()


# Creating the backend API server
app = create_app(
    lambda: _env,
    MicroSocGymAction,
    MicroSocGymObservation,
    env_name="micro_soc_gym",
    max_concurrent_envs=1,
)


# Grades the episode based on environment state and returns score with episode details
@app.get("/grade_episode")
def grade_episode() -> dict:
    score = _env.grade_episode(_env.state.scenario) # Passes scenario from state for grading reference
    return {
        "episode_id":        _env.state.episode_id,
        "scenario":          _env.state.scenario,
        "score":             score,
        "total_reward":      _env.state.total_reward,
        "steps_taken":       _env.state.step_count,
        "threat_neutralised": _env.state.threat_neutralised,
    }


# Building and mounting Gradio UI
_ui = build_ui(_env)
app = gr.mount_gradio_app(app, _ui, path="/")


def main() -> None:
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=7860)


if __name__ == "__main__":
    main()
