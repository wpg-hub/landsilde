import json
import logging
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

import yaml

BASE_DIR = Path(__file__).resolve().parent.parent
CONFIG_YAML = BASE_DIR / "config.yaml"
CONFIG_JSON = BASE_DIR / "config.json"
SCRIPTS_DIR = BASE_DIR / "scripts"
LOGS_DIR = BASE_DIR / "logs"

LOG_FORMAT = "[%(asctime)s] [%(levelname)s] [%(module)s] %(message)s"
DATE_FORMAT = "%Y-%m-%d %H:%M:%S"


def setup_logger():
    LOGS_DIR.mkdir(parents=True, exist_ok=True)
    log_file = LOGS_DIR / f"worker_{datetime.now().strftime('%Y%m%d')}.log"

    logger = logging.getLogger("landslide_worker")
    logger.setLevel(logging.DEBUG)

    file_handler = logging.FileHandler(log_file, encoding="utf-8")
    file_handler.setLevel(logging.DEBUG)
    file_handler.setFormatter(logging.Formatter(LOG_FORMAT, DATE_FORMAT))

    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(logging.INFO)
    console_handler.setFormatter(logging.Formatter(LOG_FORMAT, DATE_FORMAT))

    logger.addHandler(file_handler)
    logger.addHandler(console_handler)

    return logger


logger = setup_logger()


def load_config_yaml():
    if not CONFIG_YAML.exists():
        logger.error("config.yaml not found at %s", CONFIG_YAML)
        sys.exit(1)
    with open(CONFIG_YAML, "r", encoding="utf-8") as f:
        config = yaml.safe_load(f)
    logger.info("Loaded config.yaml: %s", config)
    return config


def load_config_json():
    if not CONFIG_JSON.exists():
        logger.error("config.json not found at %s", CONFIG_JSON)
        sys.exit(1)
    with open(CONFIG_JSON, "r", encoding="utf-8") as f:
        config = json.load(f)
    logger.info("Loaded config.json: %s", config)
    return config


def run_script(script_name):
    script_path = SCRIPTS_DIR / script_name
    if not script_path.exists():
        logger.error("Script not found: %s", script_path)
        return False

    logger.info("Executing script: %s", script_path)
    try:
        result = subprocess.run(
            ["bash", str(script_path)],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.stdout:
            for line in result.stdout.strip().splitlines():
                logger.info("[script:%s] %s", script_name, line)
        if result.stderr:
            for line in result.stderr.strip().splitlines():
                logger.warning("[script:%s] STDERR: %s", script_name, line)
        if result.returncode != 0:
            logger.error(
                "Script %s exited with code %d", script_name, result.returncode
            )
            return False
        logger.info("Script %s completed successfully", script_name)
        return True
    except subprocess.TimeoutExpired:
        logger.error("Script %s timed out after 120s", script_name)
        return False
    except Exception as e:
        logger.error("Failed to execute script %s: %s", script_name, e)
        return False


def wait_with_countdown(seconds, label=""):
    if seconds <= 0:
        logger.info("Wait time is 0, skipping wait for %s", label)
        return
    logger.info("Waiting %d seconds for %s ...", seconds, label)
    remaining = seconds
    while remaining > 0:
        if remaining > 60:
            chunk = 60
        elif remaining > 10:
            chunk = 10
        else:
            chunk = remaining
        time.sleep(chunk)
        remaining -= chunk
        if remaining > 0:
            logger.info("  ... %d seconds remaining for %s", remaining, label)
    logger.info("Wait completed for %s (%d seconds)", label, seconds)


def main():
    logger.info("=" * 60)
    logger.info("Landslide Session Worker Starting")
    logger.info("BASE_DIR: %s", BASE_DIR)
    logger.info("=" * 60)

    load_config_yaml()
    json_config = load_config_json()

    start_time = json_config.get("landsilde_starttime", 300)
    stop_time = json_config.get("landsilde_stoptime", 60)

    logger.info("Timing config: landsilde_starttime=%ds, landsilde_stoptime=%ds", start_time, stop_time)

    cycle_count = 0

    while True:
        cycle_count += 1
        logger.info("=" * 60)
        logger.info("Starting Cycle #%d", cycle_count)
        logger.info("=" * 60)

        step = 1

        logger.info("--- Step %d: Execute get_library_id.sh (1st time) ---", step)
        success = run_script("get_library_id.sh")
        if success:
            logger.info("Step %d completed successfully", step)
        else:
            logger.error("Step %d failed, continuing to next step", step)
        wait_with_countdown(5, f"after Step {step}")
        step += 1

        logger.info("--- Step %d: Execute get_library_id.sh (2nd time, confirm) ---", step)
        success = run_script("get_library_id.sh")
        if success:
            logger.info("Step %d completed successfully", step)
        else:
            logger.error("Step %d failed, continuing to next step", step)
        wait_with_countdown(5, f"after Step {step}")
        step += 1

        logger.info("--- Step %d: Execute sessionstart.sh ---", step)
        success = run_script("sessionstart.sh")
        if success:
            logger.info("Step %d completed successfully", step)
        else:
            logger.error("Step %d failed, continuing to next step", step)
        wait_with_countdown(start_time, f"session running (landsilde_starttime={start_time}s)")
        step += 1

        logger.info("--- Step %d: Execute sessionstop.sh ---", step)
        success = run_script("sessionstop.sh")
        if success:
            logger.info("Step %d completed successfully", step)
        else:
            logger.error("Step %d failed, continuing to next step", step)
        wait_with_countdown(stop_time, f"after stop (landsilde_stoptime={stop_time}s)")
        step += 1

        logger.info("--- Step %d: Execute del_running_id.sh ---", step)
        success = run_script("del_running_id.sh")
        if success:
            logger.info("Step %d completed successfully", step)
        else:
            logger.error("Step %d failed, continuing to next step", step)
        wait_with_countdown(10, f"after Step {step}")
        step += 1

        logger.info("=" * 60)
        logger.info("Cycle #%d completed", cycle_count)
        logger.info("=" * 60)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        logger.info("Worker interrupted by user, shutting down gracefully")
        sys.exit(0)
    except Exception as e:
        logger.critical("Unexpected error: %s", e, exc_info=True)
        sys.exit(1)
