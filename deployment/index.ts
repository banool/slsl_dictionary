import "./app";
import "./cron";
import "./db";
import "./iam";
import "./lb";
import "./project";
import "./storage";

import { staticIp } from "./lb";

export const ipAddress = staticIp.address;
