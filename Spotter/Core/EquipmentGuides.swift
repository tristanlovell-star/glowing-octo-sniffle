import Foundation

/// Plain-English "how do I use this thing" help for each kind of equipment.
struct EquipmentGuide {
    var summary: String
    var setup: [String]
    var tips: [String]
    var mistakes: [String]
}

extension EquipmentType {
    var guide: EquipmentGuide {
        switch self {
        case .dumbbells:
            return EquipmentGuide(
                summary: "Hand-held weights, usually racked in pairs from light to heavy. The most versatile kit in any gym: almost every muscle can be trained with them.",
                setup: [
                    "The weight printed on the end is per dumbbell, in kilograms.",
                    "Take them from the rack to a bench or a clear bit of floor — don't lift right in front of the rack, others need to get to it.",
                    "For bench work, sit with the dumbbells on your thighs, then lie back and kick them up one knee at a time.",
                ],
                tips: [
                    "Start lighter than you think. Each arm works alone, so you'll lift less than on a machine.",
                    "Lower under control for 2–3 seconds; that's where a lot of the benefit is.",
                    "Log the weight of one dumbbell, not the pair.",
                ],
                mistakes: ["Swinging the weights with momentum.", "Dropping them from height at the end of a set.", "Leaving them on the floor instead of re-racking."])
        case .barbell:
            return EquipmentGuide(
                summary: "A long steel bar loaded with weight plates. A standard Olympic bar weighs 20 kg on its own; shorter or lighter bars are often 15 kg or 10 kg.",
                setup: [
                    "Load the same plates on each side and slide them all the way to the collar.",
                    "Always fit the clips (collars) so plates can't slide off.",
                    "Total weight = the bar (usually 20 kg) + every plate on both sides.",
                ],
                tips: [
                    "Grip the bar evenly using the smooth rings in the knurling as a guide.",
                    "Brace your stomach as if about to be poked, before every rep.",
                    "For anything heavy over your face or on your back, use a rack with safety bars.",
                ],
                mistakes: ["Forgetting to count the bar's own weight.", "Unloading one side completely while the other is still loaded — the bar can flip.", "Skipping the clips."])
        case .ezBar:
            return EquipmentGuide(
                summary: "A short bar with a zig-zag bend in the middle. The angled grips are kinder to the wrists and elbows for curls and triceps work. Usually weighs 7–10 kg empty.",
                setup: ["Hold the inner angled sections for a narrow grip or the outer ones for a wider grip.", "Load plates evenly and clip them."],
                tips: ["Keep your elbows pinned to your sides on curls.", "For skull crushers, lower it toward your forehead or just behind your head, slowly."],
                mistakes: ["Leaning back and swinging on curls.", "Letting the elbows flare wide on triceps extensions."])
        case .kettlebells:
            return EquipmentGuide(
                summary: "Cast-iron balls with a handle. The off-centre weight makes them ideal for swings, goblet squats and carries.",
                setup: ["Weights are marked in kg on the side.", "For a goblet squat, hold it by the sides of the handle (the 'horns') against your chest."],
                tips: ["A swing is a hip snap, not a squat and not a front raise — the arms just guide.", "Keep your wrist straight when pressing overhead so the bell rests on your forearm."],
                mistakes: ["Rounding the lower back on swings.", "Lifting the bell with the shoulders instead of driving with the hips."])
        case .flatBench:
            return EquipmentGuide(
                summary: "A plain padded bench that doesn't adjust. Used for presses, rows, step-ups and as support for dozens of dumbbell exercises.",
                setup: ["For pressing: eyes roughly under where the weights start, feet flat on the floor.", "For one-arm rows: one knee and the same-side hand on the bench, back flat."],
                tips: ["Squeeze your shoulder blades together and down before you press.", "Keep your backside on the bench throughout."],
                mistakes: ["Feet up in the air or dancing around during presses.", "Bouncing the weight off your chest."])
        case .adjustableBench:
            return EquipmentGuide(
                summary: "A bench whose backrest (and often seat) tilts from flat up to upright. Covers flat, incline and seated exercises.",
                setup: [
                    "Find the pin or ladder under the backrest: pull the pin or lift the back and drop it into a different notch.",
                    "Incline press: 30–45 degrees (usually 2–3 notches up). Shoulder press: one notch short of fully upright.",
                    "If the seat adjusts too, tilt it up a notch on inclines so you don't slide down.",
                ],
                tips: ["Check the pin is fully home before you sit down.", "It lies fully flat, so it doubles as a flat bench."],
                mistakes: ["Setting the incline too steep — that turns a chest press into a shoulder press.", "Leaving it in a strange position for the next person."])
        case .preacherBench:
            return EquipmentGuide(
                summary: "A seat with a sloped arm pad. It locks your upper arms in place so the biceps do all the work on curls.",
                setup: ["Adjust the seat so your armpits sit snugly at the top of the pad.", "Rest the back of your upper arms flat on the pad."],
                tips: ["Lower until your arms are nearly straight, but don't lock out hard at the bottom.", "Go lighter than a standing curl — there's no cheating here."],
                mistakes: ["Lifting your elbows off the pad.", "Dropping fast into the stretched position."])
        case .squatRack:
            return EquipmentGuide(
                summary: "A steel frame with adjustable hooks to hold a barbell and safety bars to catch it. The safe place for squats, overhead presses and heavy bench work.",
                setup: [
                    "Set the hooks just below shoulder height so you can unrack by standing up, not by going on tiptoe.",
                    "Set the safety bars just below the lowest point the bar reaches in your lift.",
                    "Step under the bar, stand it up, take one or two steps back, and set your feet.",
                ],
                tips: ["Walk the bar back into the uprights first, then lower onto the hooks — don't aim for the hooks.", "Warm up with the empty bar."],
                mistakes: ["Hooks set too high.", "No safety bars when lifting alone.", "Curling in the squat rack while people wait to squat."])
        case .smithMachine:
            return EquipmentGuide(
                summary: "A barbell fixed to vertical rails. It can only move up and down, and you can lock it at any height with a twist of the wrists — great for training hard without a spotter.",
                setup: [
                    "Rotate the bar (roll your wrists) to unhook it; rotate back to hook it onto the nearest peg.",
                    "Set the safety stops on the rails just below your lowest position.",
                    "The bar is counterbalanced on many machines and can weigh anywhere from 7 to 20 kg — check the label.",
                ],
                tips: ["Position your body so the fixed path suits the lift: bench under the bar so it lands on mid-chest, feet slightly forward for squats.", "Log plates plus the bar weight shown on the machine."],
                mistakes: ["Forgetting to rotate the bar fully onto the hooks at the end.", "Standing directly under the bar for squats as you would with a free bar — put your feet a little forward."])
        case .cableStation:
            return EquipmentGuide(
                summary: "One or two weight stacks with pulleys that slide up and down a column. Clip on different handles and you can pull or push from any height.",
                setup: [
                    "Move the pulley: pull the pop-pin on the carriage, slide it to the height you want, release so it clicks in.",
                    "Pick the weight by pushing the pin into the stack.",
                    "Swap attachments with the carabiner clip: rope for triceps and face pulls, single handle for one-arm work, straight bar for curls and pushdowns.",
                ],
                tips: ["High pulley for pushdowns and face pulls; low pulley for curls and lateral raises; chest height for presses and rows.", "Stack numbers aren't always kilograms — go by feel and log the number on the plate."],
                mistakes: ["Letting the stack crash down between reps.", "Standing so close that the plates bottom out before the end of the movement."])
        case .latPulldown:
            return EquipmentGuide(
                summary: "A seat with thigh pads under a high pulley and a long bar. Trains the big back muscles — the same motion as a pull-up, with adjustable weight.",
                setup: [
                    "Adjust the thigh pads so they hold your legs down firmly when seated.",
                    "Set the pin, stand to grab the bar a bit wider than shoulders, then sit down with it.",
                    "Lean back very slightly, chest up.",
                ],
                tips: ["Pull the bar to your upper chest, leading with the elbows.", "Control it all the way back up to a full stretch."],
                mistakes: ["Pulling behind the neck.", "Leaning far back and heaving with bodyweight.", "Half reps that never let the arms straighten."])
        case .seatedCableRow:
            return EquipmentGuide(
                summary: "A bench with foot plates facing a low pulley. You pull a handle to your stomach to work the mid-back.",
                setup: ["Sit with feet on the plates and knees slightly bent.", "Reach forward to take the handle, then sit tall before the first rep."],
                tips: ["Pull to your belly button and squeeze your shoulder blades together.", "Keep your torso nearly still; a little lean forward on the stretch is fine."],
                mistakes: ["Rocking back and forth to move the weight.", "Shrugging the shoulders up to the ears."])
        case .chestPressMachine:
            return EquipmentGuide(
                summary: "A seated machine where you push handles away from your chest. A safe, stable alternative to the bench press.",
                setup: [
                    "Adjust the seat height so the handles line up with the middle of your chest.",
                    "If there's a foot lever or start-position adjuster, use it to bring the handles forward so you don't start over-stretched.",
                    "Set the pin, feet flat, back and head against the pad.",
                ],
                tips: ["Push until your arms are almost straight, then return slowly.", "Keep your shoulder blades back against the pad."],
                mistakes: ["Seat too low, so the handles are at shoulder height.", "Letting the plates slam between reps."])
        case .pecDeck:
            return EquipmentGuide(
                summary: "A seated machine with two arms that swing together in front of you (chest fly). On most, the arms also set backwards so you can face the pad and do rear-delt flys.",
                setup: [
                    "Seat height: hands and elbows level with your shoulders, or just below.",
                    "Chest fly: sit back against the pad, arms set wide.",
                    "Rear delt fly: move the arm pins to the rearmost holes, sit facing the pad.",
                ],
                tips: ["Keep a slight bend in the elbows and think 'hug a tree'.", "Pause for a second where the handles meet."],
                mistakes: ["Starting position set so wide it strains the front of the shoulders.", "Bending and straightening the elbows, which turns it into a press."])
        case .shoulderPressMachine:
            return EquipmentGuide(
                summary: "A seated machine where you push handles overhead. Trains the shoulders with your back fully supported.",
                setup: ["Adjust the seat so the handles start level with your ears or just below.", "Sit right back against the pad and set the pin."],
                tips: ["Press up without locking the elbows hard.", "Lower until your hands reach about ear height."],
                mistakes: ["Arching the lower back away from the pad.", "Seat too high, so you can only do the top half of the movement."])
        case .rowMachine:
            return EquipmentGuide(
                summary: "A seated machine with a chest pad where you pull handles toward you. A stable way to train the mid-back without loading the lower back.",
                setup: ["Seat height: handles level with your lower chest.", "Chest pad distance: you should only just reach the handles with arms straight."],
                tips: ["Lead with the elbows and squeeze your shoulder blades together.", "Keep your chest on the pad the whole time."],
                mistakes: ["Pad too close, so there's no stretch at the start.", "Pulling with the biceps and shrugging."])
        case .assistedPullupDip:
            return EquipmentGuide(
                summary: "A tower with pull-up handles, dip bars and a knee or foot platform that pushes you up. The weight you select is help: more weight makes it easier.",
                setup: [
                    "Set the pin — remember, a heavier setting means more assistance.",
                    "Climb the steps, grip the handles, then put your knees (or feet) on the platform one at a time.",
                    "To get off, lower the platform under control and step onto the side steps.",
                ],
                tips: ["Log it as a bodyweight exercise; reduce the assistance over time.", "Fold the platform away (if it hinges) once you can do unassisted reps."],
                mistakes: ["Stepping off while the platform is still loaded — it springs up.", "Choosing too little assistance and doing half reps."])
        case .legPress:
            return EquipmentGuide(
                summary: "You sit or lie back and push a weighted platform away with your feet. Trains the whole leg with your back supported.",
                setup: [
                    "Set the backrest so your hips stay down on the seat at the bottom of the rep.",
                    "Feet shoulder-width, middle of the platform.",
                    "Push the platform up, then turn the safety handles out to release it. Turn them back in before you stop.",
                ],
                tips: ["Lower until your knees are around 90 degrees or a little deeper.", "Push through your whole foot and keep knees tracking over toes."],
                mistakes: ["Locking the knees out hard at the top.", "Going so deep that your lower back peels off the seat.", "Hands pushing on the knees."])
        case .hackSquat:
            return EquipmentGuide(
                summary: "A sled on angled rails with shoulder pads. You squat with your back supported, which puts the emphasis on the quads.",
                setup: ["Shoulders under the pads, back flat on the rest, feet shoulder-width on the plate.", "Stand up, then flip the safety handles out to release."],
                tips: ["Lower slowly as deep as you can keep your heels down.", "Re-engage the safety handles at the top when finished."],
                mistakes: ["Heels lifting.", "Knees collapsing inward."])
        case .legExtension:
            return EquipmentGuide(
                summary: "A seat with a padded roller in front of your shins. You straighten your knees against it to isolate the front of the thighs.",
                setup: [
                    "Backrest: slide it so your knees line up with the machine's pivot (usually marked with a dot).",
                    "Shin pad: just above your ankles.",
                    "Set the pin and hold the side handles.",
                ],
                tips: ["Pause for a second at the top with legs straight.", "Lower for a slow count of three."],
                mistakes: ["Kicking the weight up and letting it drop.", "Knees ahead of or behind the pivot."])
        case .legCurl:
            return EquipmentGuide(
                summary: "Seated or lying, you bend your knees against a padded roller to work the back of the thighs.",
                setup: [
                    "Line your knees up with the machine's pivot point.",
                    "Roller: on the back of your lower calves, just above the heel.",
                    "Seated version: lower the thigh pad firmly onto your thighs.",
                ],
                tips: ["Curl all the way, pause, and return slowly.", "Keep your hips down — don't let them lift to help."],
                mistakes: ["Using a weight so heavy the hips lift off.", "Short, fast reps."])
        case .hipAbAdMachine:
            return EquipmentGuide(
                summary: "A seat with two leg pads. Pushing your knees apart works the outer hips; squeezing them together works the inner thighs. Many gyms have one machine that does both.",
                setup: ["Use the lever to set the start width of the pads.", "For pushing out, pads go on the outside of the knees; for squeezing in, on the inside."],
                tips: ["Move slowly and pause at the end of each rep.", "Sit tall with your back against the pad."],
                mistakes: ["Starting the inner-thigh version too wide.", "Bouncing through the reps."])
        case .calfRaiseMachine:
            return EquipmentGuide(
                summary: "Either standing under shoulder pads or seated with pads on the knees, you rise onto your toes against resistance.",
                setup: ["Balls of your feet on the edge of the step, heels hanging off.", "Adjust the pads so there's tension even at the bottom."],
                tips: ["Full stretch at the bottom, pause, then rise as high as you can and pause again.", "Slow reps beat heavy bouncy ones here."],
                mistakes: ["Bouncing out of the bottom.", "Tiny range of motion."])
        case .abCrunchMachine:
            return EquipmentGuide(
                summary: "A seated machine where you curl your torso forward against a weight stack.",
                setup: ["Adjust the seat so the pivot is around the middle of your torso.", "Hook your feet under the pads and hold the handles lightly."],
                tips: ["Curl your ribs toward your hips — think of rolling up, not folding at the hips.", "Breathe out as you crunch."],
                mistakes: ["Pulling with the arms.", "Using too much weight and hinging at the hips."])
        case .bicepCurlMachine:
            return EquipmentGuide(
                summary: "A seated machine with an arm pad and handles that guides you through a biceps curl.",
                setup: ["Seat height: upper arms flat on the pad with your elbows in line with the pivot.", "Set the pin and take an underhand grip."],
                tips: ["Curl fully, squeeze, and lower almost to straight.", "Keep your shoulders down."],
                mistakes: ["Elbows lifting off the pad.", "Dropping the weight on the way down."])
        case .tricepMachine:
            return EquipmentGuide(
                summary: "A seated machine for the back of the arms — either you press handles down beside your hips (seated dip) or extend your arms from a pad.",
                setup: ["Seat height so your elbows line up with the pivot, or so the handles start beside your ribs.", "Use the seat belt if there is one, to stop you lifting out of the seat."],
                tips: ["Press until your arms are straight and pause.", "Keep your elbows tucked in."],
                mistakes: ["Leaning your bodyweight over the handles.", "Elbows flaring wide."])
        case .backExtension:
            return EquipmentGuide(
                summary: "An angled bench that holds your legs while your upper body hangs free. You hinge down and back up to train the lower back, glutes and hamstrings.",
                setup: ["Set the hip pad just below your hip bones so you can bend freely at the hips.", "Hook your heels under the rollers."],
                tips: ["Rise until your body is a straight line — no higher.", "Hold a plate to your chest once bodyweight is easy."],
                mistakes: ["Over-arching at the top.", "Pad too high, blocking the hips."])
        case .pullUpBar:
            return EquipmentGuide(
                summary: "A fixed overhead bar. Pull-ups and chin-ups are among the best back and arm exercises; hanging leg raises train the core.",
                setup: ["Use a step if you can't reach comfortably.", "Overhand grip a bit wider than shoulders for pull-ups; underhand, shoulder-width for chin-ups."],
                tips: ["Can't do one yet? Jump to the top and lower yourself as slowly as you can.", "Start each rep by pulling your shoulders down away from your ears."],
                mistakes: ["Kicking and swinging.", "Not coming all the way down."])
        case .dipStation:
            return EquipmentGuide(
                summary: "Two parallel bars, often part of a tower with arm pads and a back rest ('captain's chair') for knee raises.",
                setup: ["Dips: grip the bars, jump or step up, arms straight.", "Knee raises: forearms on the pads, back against the rest, legs hanging."],
                tips: ["Lean forward for chest, stay upright for triceps.", "Lower until your upper arms are about parallel to the floor."],
                mistakes: ["Dropping too deep and straining the shoulders.", "Swinging the legs on knee raises."])
        case .resistanceBands:
            return EquipmentGuide(
                summary: "Elastic loops or tubes with handles. The further you stretch them, the harder they pull. Ideal for travel and warm-ups.",
                setup: ["Anchor under your feet, around a sturdy post, or in a door.", "Check for nicks or tears before loading one."],
                tips: ["Step further from the anchor or shorten your grip to add resistance.", "Slow the return — don't let the band snap you back."],
                mistakes: ["Anchoring to something that can move.", "Letting go under tension."])
        case .exerciseBall:
            return EquipmentGuide(
                summary: "A large inflatable ball. Its instability makes core and hamstring work harder.",
                setup: ["Pick a ball that puts your knees at about 90 degrees when you sit on it.", "Use it on a non-slip surface."],
                tips: ["Move slowly; control matters more than reps.", "For leg curls, keep your hips lifted the whole time."],
                mistakes: ["Using a soft, under-inflated ball.", "Rushing and losing balance."])
        case .suspensionTrainer:
            return EquipmentGuide(
                summary: "Two adjustable straps with handles hung from a high anchor. You use your bodyweight, and change the difficulty by changing your body angle.",
                setup: ["Shorten the straps for rows, lengthen to mid-shin for push-ups and core work.", "Walk your feet toward the anchor to make it harder, away to make it easier."],
                tips: ["Keep your body in a rigid plank from head to heels.", "Keep tension on the straps throughout."],
                mistakes: ["Sagging hips.", "Straps rubbing on your arms during push-ups — hands a little wider."])
        case .treadmill:
            return EquipmentGuide(
                summary: "A moving belt for walking or running indoors.",
                setup: ["Stand on the side rails, clip the safety key to your clothes, press Start, then step on.", "Build speed gradually."],
                tips: ["For a warm-up: 5 minutes of brisk walking at a 3–5% incline.", "Incline walking burns plenty without the impact of running."],
                mistakes: ["Holding the handrails while walking on an incline.", "Jumping on at speed."])
        case .bike:
            return EquipmentGuide(
                summary: "A stationary bike — upright, recumbent or spin-style.",
                setup: ["Saddle height: your leg should be almost straight at the bottom of the pedal stroke.", "Strap your feet in if there are straps."],
                tips: ["Warm-up: 5 easy minutes at a resistance you can talk through.", "For intervals: 30 seconds hard, 90 seconds easy."],
                mistakes: ["Saddle too low, which loads the knees.", "No resistance at all, spinning wildly."])
        case .rower:
            return EquipmentGuide(
                summary: "A sliding seat and a handle on a chain. A full-body cardio machine: legs, back and arms.",
                setup: ["Strap your feet across the widest part of the foot.", "Damper around 3–5 is right for most people — higher isn't 'better'."],
                tips: ["The order is legs, then lean back, then arms — and reverse on the way forward.", "Most of the power comes from the leg push."],
                mistakes: ["Pulling with the arms first.", "Rounding the back and hunching forward."])
        case .elliptical:
            return EquipmentGuide(
                summary: "A low-impact cardio machine where your feet move in an oval path while you push and pull handles.",
                setup: ["Step on, start pedalling to wake the console, then set resistance.", "Stand tall; light grip on the moving handles."],
                tips: ["Good warm-up option if your knees don't like running.", "Raise resistance rather than speed to work harder."],
                mistakes: ["Leaning on the fixed handles.", "Resistance so low you're just freewheeling."])
        case .stairClimber:
            return EquipmentGuide(
                summary: "A revolving staircase or pair of stepping pedals. Hard cardio that also works the glutes and legs.",
                setup: ["Hold the rails while you step on and start slowly.", "Pick a pace you could hold for several minutes."],
                tips: ["Stand upright and use whole-foot steps.", "Rest your hands lightly on the rails for balance only."],
                mistakes: ["Hunching over and leaning your weight on the rails.", "Starting too fast."])
        }
    }
}
