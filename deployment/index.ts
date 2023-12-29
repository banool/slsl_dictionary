import "./admin-site-cloud-run";
import "./functions";
import "./db";
import "./iam";
import "./lb";
import "./project";
import "./scheduler";
import "./storage";

import { func } from "./functions";

export const functionName = func.name;
