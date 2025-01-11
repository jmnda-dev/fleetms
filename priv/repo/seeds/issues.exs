issues =
  [
  %{
    id: 1,
    title: "Front Left Low Tire Pressure",
    description: "The front left tire pressure is lower than recommended levels.",
    possible_resolve_comment: "Tire was inflated to 220 kpa.",
    possible_close_comment: nil,
    possible_priorities: [:Low, :Medium],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [1, 3, 5],
    replacement_parts: [
      %{part_name: "Tire Inflator Kit", price: 50.00, part_number: "TIK-001"}
    ],
    service_tasks: ["Inflate Front Left Tire"]
  },
  %{
    id: 2,
    title: "Engine Oil Change Needed",
    description: "The vehicle's engine oil has surpassed the recommended mileage for a change.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium, :High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [5, 7, 15],
    replacement_parts: [
      %{part_name: "Engine Oil", price: 35.00, part_number: "EO-123"},
      %{part_name: "Engine Oil Filter", price: 15.00, part_number: "EOF-456"}
    ],
    service_tasks: ["Engine Oil Change"]
  },
  %{
    id: 3,
    title: "Battery Low Voltage",
    description:
      "The battery voltage is below the recommended level, possibly due to age or alternator issues.",
    possible_resolve_comment: "Battery terminals cleaned and recharged.",
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [1, 3, 7],
    replacement_parts: [
      %{part_name: "12V Car Battery", price: 120.00, part_number: "CB-789"},
      %{part_name: "Battery Terminal Cleaner", price: 10.00, part_number: "BTC-321"}
    ],
    service_tasks: ["Battery Replacement"]
  },
  %{
    id: 4,
    title: "Check Engine Light On",
    description: "The vehicle's check engine light is on, indicating a potential engine fault.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium, :High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15, 30],
    replacement_parts: [
      %{part_name: "OBD-II Scanner", price: 75.00, part_number: "OBD2-001"}
    ],
    service_tasks: ["Engine Diagnostics"]
  },
  %{
    id: 5,
    title: "Brake Pads Worn",
    description: "The brake pads have less than 3mm of thickness remaining.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [5, 7, 15],
    replacement_parts: [
      %{part_name: "Front Brake Pads", price: 90.00, part_number: "FBP-456"},
      %{part_name: "Rear Brake Pads", price: 85.00, part_number: "RBP-789"}
    ],
    service_tasks: ["Brake Pad Replacement"]
  },
  %{
    id: 6,
    title: "Headlight Not Functioning",
    description: "The front left headlight is not operational.",
    possible_resolve_comment: "Bulb replaced with a new H7 bulb.",
    possible_close_comment: "Driver confirmed headlight is not needed for daytime use.",
    possible_priorities: [:Low, :Medium],
    resolution_method: [:resolve_with_comment, :close_with_comment],
    estimated_num_of_days_to_resolve: [1, 3, 5]
  },
  %{
    id: 7,
    title: "Windshield Wipers Not Functioning",
    description: "Windshield wipers are not operational, likely due to motor failure.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15],
    replacement_parts: [
      %{part_name: "Wiper Motor", price: 200.00, part_number: "WM-111"},
      %{part_name: "Windshield Wipers", price: 45.00, part_number: "WW-333"}
    ],
    service_tasks: ["Windshield Wiper Motor Replacement"]
  },
  %{
    id: 8,
    title: "Air Conditioning Not Cooling",
    description: "The air conditioning system is blowing warm air.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium, :High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15, 30],
    replacement_parts: [
      %{part_name: "AC Compressor", price: 300.00, part_number: "ACC-567"},
      %{part_name: "Refrigerant", price: 50.00, part_number: "R-22"}
    ],
    service_tasks: ["AC System Service"]
  },
  %{
    id: 9,
    title: "Coolant Leak Detected",
    description:
      "A coolant leak has been spotted under the vehicle, potentially from a hose or radiator.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15, 30],
    replacement_parts: [
      %{part_name: "Radiator Hose", price: 40.00, part_number: "RH-101"},
      %{part_name: "Coolant", price: 25.00, part_number: "C-789"}
    ],
    service_tasks: ["Coolant Leak Repair"]
  },
  %{
    id: 10,
    title: "Tire Puncture",
    description: "The rear right tire has a visible puncture.",
    possible_resolve_comment: "Tire repaired with a patch.",
    possible_close_comment: "Spare tire installed; no repair needed immediately.",
    possible_priorities: [:Low, :Medium],
    resolution_method: [:resolve_with_comment, :close_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 11,
    title: "Exhaust Emissions Exceed Limit",
    description: "The vehicle's emissions exceed the permissible limit during an inspection.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 12,
    title: "Suspension Noise",
    description: "A clunking noise is heard from the suspension system during driving.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium, :High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15, 30]
  },
  %{
    id: 13,
    title: "Dashboard Display Malfunction",
    description: "The vehicle's dashboard display is flickering or not displaying correctly.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Low, :Medium],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [3, 7]
  },
  %{
    id: 14,
    title: "Rearview Mirror Loose",
    description: "The rearview mirror is loose and needs adjustment or replacement.",
    possible_resolve_comment: "Mirror tightened and repositioned.",
    possible_close_comment: "Mirror issue was not deemed critical by driver.",
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment, :close_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 15,
    title: "Clutch Slipping",
    description: "The clutch slips during gear changes, reducing vehicle performance.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium, :High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 16,
    title: "Steering Wheel Misaligned",
    description: "The steering wheel is not centered while driving straight.",
    possible_resolve_comment: "Alignment was adjusted using a calibration tool.",
    possible_close_comment: nil,
    possible_priorities: [:Low, :Medium],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [3, 7]
  },
  %{
    id: 17,
    title: "Fuel Efficiency Decreased",
    description: "The vehicle is consuming more fuel than expected for its mileage.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 18,
    title: "Horn Not Working",
    description: "The vehicle's horn is not functional.",
    possible_resolve_comment: "Horn fuse replaced and tested.",
    possible_close_comment: "Horn deemed unnecessary for the next trip.",
    possible_priorities: [:Low, :Medium],
    resolution_method: [:resolve_with_comment, :close_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 19,
    title: "Transmission Fluid Low",
    description: "Transmission fluid levels are below recommended levels.",
    possible_resolve_comment: "Transmission fluid topped up to recommended level.",
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [1, 3, 7]
  },
  %{
    id: 20,
    title: "Windshield Crack",
    description: "A crack is visible on the windshield, potentially obstructing visibility.",
    possible_resolve_comment: nil,
    possible_close_comment: "Crack deemed minor and no immediate repair required.",
    possible_priorities: [:Low, :Medium],
    resolution_method: [:close_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15, 30]
  },
  %{
    id: 21,
    title: "Parking Brake Not Engaging",
    description: "The parking brake does not engage properly, risking vehicle roll.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 22,
    title: "Radio Not Working",
    description: "The radio is not turning on or producing sound.",
    possible_resolve_comment: "Loose wiring reconnected.",
    possible_close_comment: "Radio issue ignored as non-critical.",
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment, :close_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 23,
    title: "AC Fan Noise",
    description: "A loud noise is coming from the AC fan.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 24,
    title: "Driver's Seat Adjustment Stuck",
    description: "The driver's seat adjustment lever is not working.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [3, 7]
  },
  %{
    id: 25,
    title: "Brake Pads Worn Out",
    description: "The brake pads have worn down and need replacement.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 26,
    title: "Headlight Bulb Burnt Out",
    description: "The headlight bulb is not functioning and needs replacement.",
    possible_resolve_comment: "Replaced with a new bulb.",
    possible_close_comment: "Headlight deemed unnecessary for current operation.",
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment, :close_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 27,
    title: "Engine Overheating",
    description: "The engine temperature is abnormally high.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 28,
    title: "Windshield Washer Fluid Empty",
    description: "The windshield washer fluid reservoir is empty.",
    possible_resolve_comment: "Refilled windshield washer fluid.",
    possible_close_comment: nil,
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1]
  },
  %{
    id: 29,
    title: "Battery Not Charging",
    description: "The vehicle's battery is not charging properly.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 30,
    title: "Gear Shifting Difficulty",
    description: "The transmission is struggling to shift gears smoothly.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium, :High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 31,
    title: "Tire Alignment Issue",
    description: "The tires are not aligned, causing uneven wear.",
    possible_resolve_comment: "Alignment corrected using a calibration tool.",
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [3, 7]
  },
  %{
    id: 32,
    title: "Seat Belt Not Retracting",
    description: "The seat belt does not retract after being pulled.",
    possible_resolve_comment: "Mechanism lubricated and repaired.",
    possible_close_comment: nil,
    possible_priorities: [:Low, :Medium],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [1, 3, 7]
  },
  %{
    id: 33,
    title: "Power Steering Fluid Low",
    description: "The power steering fluid level is below the minimum requirement.",
    possible_resolve_comment: "Fluid topped up to recommended level.",
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 34,
    title: "Rear Taillight Cracked",
    description: "The rear taillight cover is cracked but still functional.",
    possible_resolve_comment: nil,
    possible_close_comment: "Crack deemed minor and no immediate repair needed.",
    possible_priorities: [:Low],
    resolution_method: [:close_with_comment],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 35,
    title: "Oil Leak Detected",
    description: "Oil spots found under the parked vehicle indicate a leak.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 36,
    title: "AC Not Cooling",
    description: "The air conditioning system is blowing warm air.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 37,
    title: "Reverse Lights Not Working",
    description: "The reverse lights do not turn on when reversing.",
    possible_resolve_comment: "Reverse light bulb replaced.",
    possible_close_comment: nil,
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 38,
    title: "Window Not Rolling Up",
    description: "The driver's side window does not roll up fully.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 39,
    title: "Radiator Coolant Low",
    description: "The radiator coolant level is below the recommended range.",
    possible_resolve_comment: "Coolant refilled to the required level.",
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 40,
    title: "Spare Tire Missing",
    description: "The spare tire is not in the designated compartment.",
    possible_resolve_comment: "Spare tire replaced.",
    possible_close_comment: "Spare tire deemed unnecessary for current usage.",
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment, :close_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 41,
    title: "Exhaust Pipe Corrosion",
    description: "The exhaust pipe shows significant signs of rust and corrosion.",
    possible_resolve_comment: nil,
    possible_close_comment: "Corrosion deemed non-critical for operation.",
    possible_priorities: [:Medium, :High],
    resolution_method: [:resolve_with_work_order, :close_with_comment],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 42,
    title: "Horn Not Working",
    description: "The horn is unresponsive when pressed.",
    possible_resolve_comment: "Horn connection repaired and tested.",
    possible_close_comment: nil,
    possible_priorities: [:Low, :Medium],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [1, 3, 7]
  },
  %{
    id: 43,
    title: "Dashboard Warning Light On",
    description: "An unidentified warning light is active on the dashboard.",
    possible_resolve_comment: "Warning light reset after diagnostics showed no issues.",
    possible_close_comment: "No significant issues detected; warning ignored.",
    possible_priorities: [:Low, :Medium, :High],
    resolution_method: [:resolve_with_comment, :close_with_comment],
    estimated_num_of_days_to_resolve: [1, 3, 7]
  },
  %{
    id: 44,
    title: "Windshield Crack",
    description: "A visible crack on the windshield has appeared.",
    possible_resolve_comment: nil,
    possible_close_comment: "Crack deemed minor; no repair necessary.",
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_work_order, :close_with_comment],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 45,
    title: "Air Filter Clogged",
    description: "The air filter is clogged and requires cleaning or replacement.",
    possible_resolve_comment: "Air filter cleaned and reinstalled.",
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [1, 3, 7]
  },
  %{
    id: 46,
    title: "Suspension Noise",
    description: "The suspension is making unusual creaking noises during movement.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium, :High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 47,
    title: "Key Fob Battery Low",
    description: "The key fob battery is running low and needs replacement.",
    possible_resolve_comment: "Key fob battery replaced successfully.",
    possible_close_comment: nil,
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1]
  },
  %{
    id: 48,
    title: "Door Handle Broken",
    description: "The exterior door handle on the driver's side is broken.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 49,
    title: "Rearview Mirror Loose",
    description: "The rearview mirror is loose and may detach.",
    possible_resolve_comment: "Mirror tightened and secured.",
    possible_close_comment: nil,
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 50,
    title: "Fuel Cap Missing",
    description: "The fuel cap is missing, leading to potential fuel evaporation.",
    possible_resolve_comment: "Replaced with a new fuel cap.",
    possible_close_comment: nil,
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 51,
    title: "Tire Balancing Issue",
    description: "The vehicle experiences vibrations due to unbalanced tires.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 52,
    title: "Cabin Light Not Working",
    description: "The cabin light fails to turn on.",
    possible_resolve_comment: "Lightbulb replaced and tested.",
    possible_close_comment: nil,
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 53,
    title: "Parking Brake Not Engaging",
    description: "The parking brake does not engage fully.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 54,
    title: "Rear Suspension Sagging",
    description: "The rear suspension sags under normal load.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 55,
    title: "Defroster Not Working",
    description: "The defroster fails to clear condensation from the windshield.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 41,
    title: "Exhaust Pipe Corrosion",
    description: "The exhaust pipe shows significant signs of rust and corrosion.",
    possible_resolve_comment: nil,
    possible_close_comment: "Corrosion deemed non-critical for operation.",
    possible_priorities: [:Medium, :High],
    resolution_method: [:resolve_with_work_order, :close_with_comment],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 42,
    title: "Horn Not Working",
    description: "The horn is unresponsive when pressed.",
    possible_resolve_comment: "Horn connection repaired and tested.",
    possible_close_comment: nil,
    possible_priorities: [:Low, :Medium],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [1, 3, 7]
  },
  %{
    id: 43,
    title: "Dashboard Warning Light On",
    description: "An unidentified warning light is active on the dashboard.",
    possible_resolve_comment: "Warning light reset after diagnostics showed no issues.",
    possible_close_comment: "No significant issues detected; warning ignored.",
    possible_priorities: [:Low, :Medium, :High],
    resolution_method: [:resolve_with_comment, :close_with_comment],
    estimated_num_of_days_to_resolve: [1, 3, 7]
  },
  %{
    id: 44,
    title: "Windshield Crack",
    description: "A visible crack on the windshield has appeared.",
    possible_resolve_comment: nil,
    possible_close_comment: "Crack deemed minor; no repair necessary.",
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_work_order, :close_with_comment],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 45,
    title: "Air Filter Clogged",
    description: "The air filter is clogged and requires cleaning or replacement.",
    possible_resolve_comment: "Air filter cleaned and reinstalled.",
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [1, 3, 7]
  },
  %{
    id: 46,
    title: "Suspension Noise",
    description: "The suspension is making unusual creaking noises during movement.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium, :High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 47,
    title: "Key Fob Battery Low",
    description: "The key fob battery is running low and needs replacement.",
    possible_resolve_comment: "Key fob battery replaced successfully.",
    possible_close_comment: nil,
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1]
  },
  %{
    id: 48,
    title: "Door Handle Broken",
    description: "The exterior door handle on the driver's side is broken.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 49,
    title: "Rearview Mirror Loose",
    description: "The rearview mirror is loose and may detach.",
    possible_resolve_comment: "Mirror tightened and secured.",
    possible_close_comment: nil,
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 50,
    title: "Fuel Cap Missing",
    description: "The fuel cap is missing, leading to potential fuel evaporation.",
    possible_resolve_comment: "Replaced with a new fuel cap.",
    possible_close_comment: nil,
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 51,
    title: "Tire Balancing Issue",
    description: "The vehicle experiences vibrations due to unbalanced tires.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 52,
    title: "Cabin Light Not Working",
    description: "The cabin light fails to turn on.",
    possible_resolve_comment: "Lightbulb replaced and tested.",
    possible_close_comment: nil,
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 53,
    title: "Parking Brake Not Engaging",
    description: "The parking brake does not engage fully.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 54,
    title: "Rear Suspension Sagging",
    description: "The rear suspension sags under normal load.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 55,
    title: "Defroster Not Working",
    description: "The defroster fails to clear condensation from the windshield.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 56,
    title: "Seat Belt Not Retracting",
    description: "The driver's seat belt is not retracting properly.",
    possible_resolve_comment: "Mechanism cleaned and seat belt retracts normally.",
    possible_close_comment: nil,
    possible_priorities: [:Low, :Medium],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [1, 3, 7]
  },
  %{
    id: 57,
    title: "Power Window Stuck",
    description: "The front passenger power window is stuck and won't move.",
    possible_resolve_comment: "Lubrication applied; window now functions normally.",
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [1, 7, 15]
  },
  %{
    id: 58,
    title: "Coolant Leak Detected",
    description: "A coolant leak is visible under the vehicle.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15, 30]
  },
  %{
    id: 59,
    title: "Turn Signal Bulb Burnt Out",
    description: "The rear left turn signal bulb is not functioning.",
    possible_resolve_comment: "Bulb replaced and tested.",
    possible_close_comment: nil,
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 60,
    title: "Brake Fluid Level Low",
    description: "The brake fluid level is below the recommended threshold.",
    possible_resolve_comment: "Brake fluid topped up to recommended level.",
    possible_close_comment: nil,
    possible_priorities: [:Medium, :High],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1, 3, 7]
  },
  %{
    id: 61,
    title: "Loose Battery Terminal",
    description: "The battery terminal connection is loose.",
    possible_resolve_comment: "Battery terminal tightened securely.",
    possible_close_comment: nil,
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1]
  },
  %{
    id: 62,
    title: "Windshield Wiper Motor Failure",
    description: "The windshield wipers do not respond when activated.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15]
  },
  %{
    id: 63,
    title: "Oil Filter Clogged",
    description: "The oil filter is clogged and needs replacement.",
    possible_resolve_comment: "Oil filter replaced.",
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [1, 7]
  },
  %{
    id: 64,
    title: "Engine Misfire Detected",
    description: "The engine is experiencing intermittent misfires.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 65,
    title: "Transmission Fluid Overheating",
    description: "The transmission fluid is overheating under load.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [15, 30]
  },
  %{
    id: 66,
    title: "Parking Sensor Malfunction",
    description: "The parking sensors are giving false positives.",
    possible_resolve_comment: "Sensors recalibrated and tested.",
    possible_close_comment: nil,
    possible_priorities: [:Low, :Medium],
    resolution_method: [:resolve_with_comment, :resolve_with_work_order],
    estimated_num_of_days_to_resolve: [3, 7, 15]
  },
  %{
    id: 67,
    title: "Fuel Pump Noise",
    description: "Unusual noise coming from the fuel pump.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium, :High],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15, 30]
  },
  %{
    id: 68,
    title: "Rear Brake Light Not Working",
    description: "The rear right brake light is not illuminating.",
    possible_resolve_comment: "Brake light bulb replaced.",
    possible_close_comment: nil,
    possible_priorities: [:Low],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1, 3]
  },
  %{
    id: 69,
    title: "Headlight Misaligned",
    description: "The right headlight beam is misaligned.",
    possible_resolve_comment: "Headlight adjusted to proper angle.",
    possible_close_comment: nil,
    possible_priorities: [:Low, :Medium],
    resolution_method: [:resolve_with_comment],
    estimated_num_of_days_to_resolve: [1, 3, 7]
  },
  %{
    id: 70,
    title: "Heater Not Producing Warm Air",
    description: "The cabin heater is not warming the interior.",
    possible_resolve_comment: nil,
    possible_close_comment: nil,
    possible_priorities: [:Medium],
    resolution_method: [:resolve_with_work_order],
    estimated_num_of_days_to_resolve: [7, 15]
  }
]


File.write!("issues.json", Jason.encode!(issues))
