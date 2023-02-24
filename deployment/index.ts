import "./app";
import "./functions";
import "./db";
import "./iam";
import "./lb";
import "./project";
import "./scheduler";
import "./storage";

import { func } from "./functions";
import { staticIp } from "./lb";

export const ipAddress = staticIp.address;
export const functionName = func.name;
