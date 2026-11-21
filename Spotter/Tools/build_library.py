#!/usr/bin/env python3
"""Builds Spotter's bundled exercise library.

Takes a curated subset of the public-domain Free Exercise DB
(https://github.com/yuhonas/free-exercise-db, Unlicense), tags each exercise with
Spotter's movement pattern and equipment requirements, and downloads two
demonstration photos (start and finish position) per exercise.

    python3 Tools/build_library.py          # run from the Spotter folder

Writes Resources/exercises.json and Resources/ExerciseImages/*.jpg.
"""
import io
import json
import sys
import urllib.request
from pathlib import Path

from PIL import Image

BASE = "https://raw.githubusercontent.com/yuhonas/free-exercise-db/main"
ROOT = Path(__file__).resolve().parent.parent
IMG_DIR = ROOT / "Resources" / "ExerciseImages"
IMG_WIDTH = 640

W, B, T = "weighted", "bodyweight", "timed"

# (db id, display name or None, pattern, requiresAny, difficulty 1-3, tier 1-3, load type)
# requiresAny: any ONE of the listed equipment sets is enough. [[]] = no equipment.
# tier 1 = staple the program builder prefers, 3 = fallback / variety.
CURATED = [
    # --- horizontal push
    ("Barbell_Bench_Press_-_Medium_Grip", "Barbell Bench Press", "horizontalPush", [["barbell", "flatBench"]], 2, 1, W),
    ("Dumbbell_Bench_Press", None, "horizontalPush", [["dumbbells", "flatBench"]], 1, 1, W),
    ("Machine_Bench_Press", "Machine Chest Press", "horizontalPush", [["chestPressMachine"]], 1, 1, W),
    ("Smith_Machine_Bench_Press", None, "horizontalPush", [["smithMachine", "flatBench"]], 1, 2, W),
    ("Standing_Cable_Chest_Press", None, "horizontalPush", [["cableStation"]], 2, 2, W),
    ("Pushups", "Push-Up", "horizontalPush", [[]], 1, 2, B),
    ("Incline_Push-Up", None, "horizontalPush", [[]], 1, 3, B),
    ("Dips_-_Chest_Version", "Chest Dip", "horizontalPush", [["dipStation"], ["assistedPullupDip"]], 3, 2, B),
    ("Suspended_Push-Up", "Suspension Trainer Push-Up", "horizontalPush", [["suspensionTrainer"]], 2, 3, B),
    # --- incline push
    ("Barbell_Incline_Bench_Press_-_Medium_Grip", "Incline Barbell Bench Press", "inclinePush", [["barbell", "adjustableBench"]], 2, 1, W),
    ("Incline_Dumbbell_Press", None, "inclinePush", [["dumbbells", "adjustableBench"]], 1, 1, W),
    ("Smith_Machine_Incline_Bench_Press", None, "inclinePush", [["smithMachine", "adjustableBench"]], 1, 2, W),
    ("Incline_Cable_Chest_Press", None, "inclinePush", [["cableStation", "adjustableBench"]], 2, 3, W),
    ("Push-Ups_With_Feet_Elevated", "Feet-Elevated Push-Up", "inclinePush", [[]], 2, 2, B),
    # --- vertical push
    ("Standing_Military_Press", "Standing Barbell Overhead Press", "verticalPush", [["barbell"]], 2, 1, W),
    ("Seated_Dumbbell_Press", "Seated Dumbbell Shoulder Press", "verticalPush", [["dumbbells", "adjustableBench"]], 1, 1, W),
    ("Standing_Dumbbell_Press", "Standing Dumbbell Shoulder Press", "verticalPush", [["dumbbells"]], 1, 2, W),
    ("Machine_Shoulder_Military_Press", "Machine Shoulder Press", "verticalPush", [["shoulderPressMachine"]], 1, 1, W),
    ("Smith_Machine_Overhead_Shoulder_Press", "Smith Machine Shoulder Press", "verticalPush", [["smithMachine", "adjustableBench"]], 1, 2, W),
    ("Cable_Shoulder_Press", None, "verticalPush", [["cableStation"]], 2, 3, W),
    ("Two-Arm_Kettlebell_Military_Press", "Kettlebell Overhead Press", "verticalPush", [["kettlebells"]], 2, 2, W),
    ("Shoulder_Press_-_With_Bands", "Band Shoulder Press", "verticalPush", [["resistanceBands"]], 1, 3, W),
    # --- horizontal pull
    ("Bent_Over_Barbell_Row", "Barbell Bent-Over Row", "horizontalPull", [["barbell"]], 2, 1, W),
    ("One-Arm_Dumbbell_Row", None, "horizontalPull", [["dumbbells", "flatBench"]], 1, 1, W),
    ("Seated_Cable_Rows", "Seated Cable Row", "horizontalPull", [["seatedCableRow"]], 1, 1, W),
    ("Leverage_Iso_Row", "Machine Row", "horizontalPull", [["rowMachine"]], 1, 1, W),
    ("Seated_One-arm_Cable_Pulley_Rows", "Single-Arm Cable Row", "horizontalPull", [["cableStation"]], 1, 2, W),
    ("Bent_Over_Two-Dumbbell_Row", "Bent-Over Dumbbell Row", "horizontalPull", [["dumbbells"]], 2, 2, W),
    ("Dumbbell_Incline_Row", "Chest-Supported Dumbbell Row", "horizontalPull", [["dumbbells", "adjustableBench"]], 1, 2, W),
    ("Smith_Machine_Bent_Over_Row", None, "horizontalPull", [["smithMachine"]], 2, 3, W),
    ("Suspended_Row", "Suspension Trainer Row", "horizontalPull", [["suspensionTrainer"]], 1, 2, B),
    ("Two-Arm_Kettlebell_Row", "Kettlebell Row", "horizontalPull", [["kettlebells"]], 2, 3, W),
    # --- vertical pull
    ("Wide-Grip_Lat_Pulldown", "Lat Pulldown", "verticalPull", [["latPulldown"]], 1, 1, W),
    ("Close-Grip_Front_Lat_Pulldown", "Close-Grip Lat Pulldown", "verticalPull", [["latPulldown"]], 1, 2, W),
    ("Underhand_Cable_Pulldowns", "Underhand Lat Pulldown", "verticalPull", [["latPulldown"]], 1, 3, W),
    ("Pullups", "Pull-Up", "verticalPull", [["pullUpBar"], ["assistedPullupDip"]], 3, 1, B),
    ("Chin-Up", None, "verticalPull", [["pullUpBar"], ["assistedPullupDip"]], 3, 2, B),
    ("Band_Assisted_Pull-Up", None, "verticalPull", [["pullUpBar", "resistanceBands"]], 2, 2, B),
    ("Kneeling_High_Pulley_Row", "Kneeling Cable Pulldown", "verticalPull", [["cableStation"]], 1, 2, W),
    ("Straight-Arm_Pulldown", "Straight-Arm Cable Pulldown", "verticalPull", [["cableStation"], ["latPulldown"]], 1, 3, W),
    # --- squat
    ("Barbell_Squat", "Barbell Back Squat", "squat", [["barbell", "squatRack"]], 3, 1, W),
    ("Leg_Press", None, "squat", [["legPress"]], 1, 1, W),
    ("Hack_Squat", "Hack Squat Machine", "squat", [["hackSquat"]], 2, 1, W),
    ("Smith_Machine_Squat", None, "squat", [["smithMachine"]], 2, 2, W),
    ("Goblet_Squat", None, "squat", [["kettlebells"], ["dumbbells"]], 1, 1, W),
    ("Front_Barbell_Squat", "Barbell Front Squat", "squat", [["barbell", "squatRack"]], 3, 3, W),
    ("Dumbbell_Squat", None, "squat", [["dumbbells"]], 1, 3, W),
    ("Squats_-_With_Bands", "Band Squat", "squat", [["resistanceBands"]], 1, 3, W),
    ("Bodyweight_Squat", None, "squat", [[]], 1, 3, B),
    # --- lunge / single leg
    ("Split_Squat_with_Dumbbells", "Bulgarian Split Squat", "lunge", [["dumbbells", "flatBench"]], 2, 1, W),
    ("Dumbbell_Lunges", "Dumbbell Lunge", "lunge", [["dumbbells"]], 1, 1, W),
    ("Dumbbell_Rear_Lunge", "Dumbbell Reverse Lunge", "lunge", [["dumbbells"]], 1, 2, W),
    ("Dumbbell_Step_Ups", "Dumbbell Step-Up", "lunge", [["dumbbells", "flatBench"]], 1, 2, W),
    ("Barbell_Lunge", None, "lunge", [["barbell", "squatRack"]], 2, 3, W),
    ("Smith_Single-Leg_Split_Squat", "Smith Machine Split Squat", "lunge", [["smithMachine"]], 2, 3, W),
    ("Bodyweight_Walking_Lunge", "Walking Lunge", "lunge", [[]], 1, 2, B),
    # --- hinge
    ("Romanian_Deadlift", "Barbell Romanian Deadlift", "hinge", [["barbell"]], 2, 1, W),
    ("Barbell_Deadlift", None, "hinge", [["barbell"]], 3, 2, W),
    ("Stiff-Legged_Dumbbell_Deadlift", "Dumbbell Romanian Deadlift", "hinge", [["dumbbells"]], 1, 1, W),
    ("Hyperextensions_Back_Extensions", "Back Extension", "hinge", [["backExtension"]], 1, 2, B),
    ("Pull_Through", "Cable Pull-Through", "hinge", [["cableStation"]], 1, 2, W),
    ("One-Arm_Kettlebell_Swings", "Kettlebell Swing", "hinge", [["kettlebells"]], 2, 2, W),
    ("Smith_Machine_Stiff-Legged_Deadlift", "Smith Machine Romanian Deadlift", "hinge", [["smithMachine"]], 2, 3, W),
    ("Kettlebell_One-Legged_Deadlift", "Single-Leg Kettlebell Deadlift", "hinge", [["kettlebells"], ["dumbbells"]], 2, 3, W),
    ("Band_Good_Morning", None, "hinge", [["resistanceBands"]], 1, 3, W),
    # --- glutes
    ("Barbell_Hip_Thrust", None, "glute", [["barbell", "flatBench"]], 2, 1, W),
    ("Barbell_Glute_Bridge", None, "glute", [["barbell"]], 2, 2, W),
    ("One-Legged_Cable_Kickback", "Cable Glute Kickback", "glute", [["cableStation"]], 1, 2, W),
    ("Butt_Lift_Bridge", "Glute Bridge", "glute", [[]], 1, 2, B),
    ("Single_Leg_Glute_Bridge", "Single-Leg Glute Bridge", "glute", [[]], 1, 2, B),
    ("Physioball_Hip_Bridge", "Exercise Ball Hip Bridge", "glute", [["exerciseBall"]], 1, 3, B),
    # --- quad isolation
    ("Leg_Extensions", "Leg Extension", "kneeExtension", [["legExtension"]], 1, 1, W),
    # --- hamstring isolation
    ("Seated_Leg_Curl", None, "kneeFlexion", [["legCurl"]], 1, 1, W),
    ("Lying_Leg_Curls", "Lying Leg Curl", "kneeFlexion", [["legCurl"]], 1, 2, W),
    ("Ball_Leg_Curl", "Exercise Ball Leg Curl", "kneeFlexion", [["exerciseBall"]], 2, 2, B),
    ("Seated_Band_Hamstring_Curl", None, "kneeFlexion", [["resistanceBands"]], 1, 3, W),
    # --- chest fly
    ("Butterfly", "Pec Deck Fly", "chestFly", [["pecDeck"]], 1, 1, W),
    ("Cable_Crossover", None, "chestFly", [["cableStation"]], 2, 1, W),
    ("Dumbbell_Flyes", "Dumbbell Fly", "chestFly", [["dumbbells", "flatBench"]], 2, 2, W),
    ("Incline_Dumbbell_Flyes", "Incline Dumbbell Fly", "chestFly", [["dumbbells", "adjustableBench"]], 2, 3, W),
    ("Low_Cable_Crossover", "Low-to-High Cable Fly", "chestFly", [["cableStation"]], 2, 3, W),
    ("Cross_Over_-_With_Bands", "Band Chest Fly", "chestFly", [["resistanceBands"]], 1, 3, W),
    # --- lateral raise
    ("Side_Lateral_Raise", "Dumbbell Lateral Raise", "lateralRaise", [["dumbbells"]], 1, 1, W),
    ("Standing_Low-Pulley_Deltoid_Raise", "Cable Lateral Raise", "lateralRaise", [["cableStation"]], 1, 1, W),
    ("Seated_Side_Lateral_Raise", "Seated Dumbbell Lateral Raise", "lateralRaise", [["dumbbells", "flatBench"]], 1, 2, W),
    ("Lateral_Raise_-_With_Bands", "Band Lateral Raise", "lateralRaise", [["resistanceBands"]], 1, 3, W),
    # --- rear delts / upper back
    ("Reverse_Machine_Flyes", "Reverse Pec Deck Fly", "rearDelt", [["pecDeck"]], 1, 1, W),
    ("Face_Pull", "Cable Face Pull", "rearDelt", [["cableStation"]], 1, 1, W),
    ("Seated_Bent-Over_Rear_Delt_Raise", "Dumbbell Rear Delt Raise", "rearDelt", [["dumbbells"]], 1, 2, W),
    ("Cable_Rear_Delt_Fly", None, "rearDelt", [["cableStation"]], 2, 3, W),
    ("Band_Pull_Apart", None, "rearDelt", [["resistanceBands"]], 1, 2, W),
    # --- biceps
    ("Dumbbell_Bicep_Curl", "Dumbbell Biceps Curl", "bicepCurl", [["dumbbells"]], 1, 1, W),
    ("Barbell_Curl", None, "bicepCurl", [["barbell"]], 1, 1, W),
    ("EZ-Bar_Curl", None, "bicepCurl", [["ezBar"]], 1, 1, W),
    ("Standing_Biceps_Cable_Curl", "Cable Biceps Curl", "bicepCurl", [["cableStation"]], 1, 1, W),
    ("Machine_Bicep_Curl", "Machine Biceps Curl", "bicepCurl", [["bicepCurlMachine"]], 1, 1, W),
    ("Hammer_Curls", "Hammer Curl", "bicepCurl", [["dumbbells"]], 1, 2, W),
    ("Incline_Dumbbell_Curl", None, "bicepCurl", [["dumbbells", "adjustableBench"]], 1, 2, W),
    ("Preacher_Curl", None, "bicepCurl", [["preacherBench", "ezBar"], ["preacherBench", "barbell"]], 1, 2, W),
    ("Concentration_Curls", "Concentration Curl", "bicepCurl", [["dumbbells", "flatBench"]], 1, 3, W),
    # --- triceps
    ("Triceps_Pushdown_-_Rope_Attachment", "Rope Triceps Pushdown", "tricepExt", [["cableStation"], ["latPulldown"]], 1, 1, W),
    ("Triceps_Pushdown", "Bar Triceps Pushdown", "tricepExt", [["cableStation"], ["latPulldown"]], 1, 2, W),
    ("Cable_Rope_Overhead_Triceps_Extension", "Overhead Cable Triceps Extension", "tricepExt", [["cableStation"]], 1, 2, W),
    ("Machine_Triceps_Extension", None, "tricepExt", [["tricepMachine"]], 1, 1, W),
    ("EZ-Bar_Skullcrusher", "EZ-Bar Skull Crusher", "tricepExt", [["ezBar", "flatBench"]], 2, 1, W),
    ("Standing_Dumbbell_Triceps_Extension", "Overhead Dumbbell Triceps Extension", "tricepExt", [["dumbbells"]], 1, 1, W),
    ("Tricep_Dumbbell_Kickback", "Dumbbell Triceps Kickback", "tricepExt", [["dumbbells"]], 1, 3, W),
    ("Close-Grip_Barbell_Bench_Press", None, "tricepExt", [["barbell", "flatBench"]], 2, 2, W),
    ("Dips_-_Triceps_Version", "Triceps Dip", "tricepExt", [["dipStation"], ["assistedPullupDip"]], 3, 2, B),
    ("Bench_Dips", "Bench Dip", "tricepExt", [["flatBench"]], 1, 2, B),
    ("Push-Ups_-_Close_Triceps_Position", "Close-Grip Push-Up", "tricepExt", [[]], 2, 2, B),
    ("Speed_Band_Overhead_Triceps", "Band Overhead Triceps Extension", "tricepExt", [["resistanceBands"]], 1, 3, W),
    # --- calves
    ("Standing_Calf_Raises", "Standing Calf Raise Machine", "calf", [["calfRaiseMachine"]], 1, 1, W),
    ("Seated_Calf_Raise", "Seated Calf Raise Machine", "calf", [["calfRaiseMachine"]], 1, 2, W),
    ("Calf_Press_On_The_Leg_Press_Machine", "Leg Press Calf Raise", "calf", [["legPress"]], 1, 1, W),
    ("Smith_Machine_Calf_Raise", None, "calf", [["smithMachine"]], 1, 2, W),
    ("Standing_Dumbbell_Calf_Raise", None, "calf", [["dumbbells"]], 1, 1, W),
    ("Calf_Raises_-_With_Bands", "Band Calf Raise", "calf", [["resistanceBands"]], 1, 3, W),
    # --- core
    ("Plank", None, "core", [[]], 1, 1, T),
    ("Cable_Crunch", None, "core", [["cableStation"], ["latPulldown"]], 1, 1, W),
    ("Ab_Crunch_Machine", "Ab Crunch Machine", "core", [["abCrunchMachine"]], 1, 1, W),
    ("Hanging_Leg_Raise", None, "core", [["pullUpBar"]], 3, 2, B),
    ("Knee_Hip_Raise_On_Parallel_Bars", "Captain's Chair Knee Raise", "core", [["dipStation"]], 2, 1, B),
    ("Pallof_Press", "Cable Pallof Press", "core", [["cableStation"]], 1, 2, W),
    ("Standing_Cable_Wood_Chop", "Cable Wood Chop", "core", [["cableStation"]], 1, 3, W),
    ("Exercise_Ball_Crunch", None, "core", [["exerciseBall"]], 1, 2, B),
    ("Dead_Bug", None, "core", [[]], 1, 1, B),
    ("Reverse_Crunch", None, "core", [[]], 1, 2, B),
    ("Crunches", "Crunch", "core", [[]], 1, 2, B),
    ("Air_Bike", "Bicycle Crunch", "core", [[]], 1, 2, B),
    ("Russian_Twist", None, "core", [[]], 1, 3, B),
    ("Side_Bridge", "Side Plank", "core", [[]], 1, 2, T),
    ("Flat_Bench_Lying_Leg_Raise", "Lying Leg Raise", "core", [["flatBench"], []], 2, 2, B),
    ("Mountain_Climbers", "Mountain Climber", "core", [[]], 1, 3, B),
    # --- hips
    ("Thigh_Abductor", "Hip Abduction Machine", "hipAbduction", [["hipAbAdMachine"]], 1, 1, W),
    ("Monster_Walk", "Band Monster Walk", "hipAbduction", [["resistanceBands"]], 1, 2, B),
    ("Thigh_Adductor", "Hip Adduction Machine", "hipAdduction", [["hipAbAdMachine"]], 1, 1, W),
    ("Band_Hip_Adductions", "Band Hip Adduction", "hipAdduction", [["resistanceBands"]], 1, 2, W),
    ("Cable_Hip_Adduction", None, "hipAdduction", [["cableStation"]], 1, 2, W),
]


def fetch(url):
    with urllib.request.urlopen(url, timeout=60) as r:
        return r.read()


def main():
    db_path = sys.argv[1] if len(sys.argv) > 1 else None
    raw = Path(db_path).read_bytes() if db_path else fetch(f"{BASE}/dist/exercises.json")
    db = {e["id"]: e for e in json.loads(raw)}
    IMG_DIR.mkdir(parents=True, exist_ok=True)
    wanted = set()
    out = []
    for db_id, name, pattern, requires, difficulty, tier, load in CURATED:
        e = db[db_id]  # KeyError here means a typo in CURATED
        images = []
        for i, rel in enumerate(e["images"][:2]):
            fname = f"{db_id}_{i}.jpg"
            wanted.add(fname)
            dest = IMG_DIR / fname
            if not dest.exists():
                img = Image.open(io.BytesIO(fetch(f"{BASE}/exercises/{rel}"))).convert("RGB")
                img.thumbnail((IMG_WIDTH, IMG_WIDTH))
                img.save(dest, "JPEG", quality=72, optimize=True)
                print("fetched", fname)
            images.append(fname[:-4])
        out.append({
            "id": db_id,
            "name": name or e["name"],
            "pattern": pattern,
            "requiresAny": requires,
            "primaryMuscles": e["primaryMuscles"],
            "secondaryMuscles": e["secondaryMuscles"],
            "instructions": [s.strip() for s in e["instructions"] if s.strip()],
            "compound": e.get("mechanic") == "compound",
            "difficulty": difficulty,
            "tier": tier,
            "loadType": load,
            "images": images,
        })
    for stale in IMG_DIR.glob("*.jpg"):
        if stale.name not in wanted:
            stale.unlink()
    ids = [e["id"] for e in out]
    assert len(ids) == len(set(ids)), "duplicate exercise id"
    (ROOT / "Resources" / "exercises.json").write_text(json.dumps(out, indent=1, ensure_ascii=False) + "\n")
    print(f"wrote {len(out)} exercises, {len(wanted)} images")


if __name__ == "__main__":
    main()
