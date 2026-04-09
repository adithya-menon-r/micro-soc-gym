# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.
#
# This source code is licensed under the BSD-style license found in the
# LICENSE file in the root directory of this source tree.

from typing import Literal, Optional
from openenv.core.env_server import Action, Observation, State


class MicroSocGymAction(Action):
    tool: Literal["block_ip", "delete_file", "kill_process", "read_access_log", "read_auth_log"]
    ip_address: Optional[str] = None
    file_path: Optional[str] = None
    pid: Optional[int] = None
    

class MicroSocGymObservation(Observation):
    logs: str
    reward: float
    done: bool
    success: bool
    info: str


class MicroSocGymState(State):
    episode_id: str = ""
    step_count: int = 0
    scenario: str = ""
    total_reward: float = 0.0
    threat_neutralised: bool = False
    investigated: bool = False