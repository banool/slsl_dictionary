import "./admin-site-cloud-run";
import "./db";
import "./iam";
import "./lb";
import "./project";
import "./storage";

import { mediaCdnIp } from "./storage";

export const mediaCdnIpAddress = mediaCdnIp.address;
