import { workload } from './lib/customer-workload.js';
const test = workload('write');
export const options = test.options;
export const setup = test.setup;
export const teardown = test.teardown;
export default test.run;
