import { Fr, createPXEClient, deriveMasterIncomingViewingSecretKey } from '@aztec/aztec.js';
import { DegenScoreContractArtifact } from '../artifacts/DegenScore';
import { AccountManager } from '@aztec/aztec.js/account';
import { SingleKeyAccountContract } from '@aztec/accounts/single_key';

const SECRET_KEY = Fr.random();

export class PrivateEnv {
  pxe;
  accountContract;
  account: AccountManager;

  constructor(
    private secretKey: Fr,
    private pxeURL: string,
  ) {
    this.pxe = createPXEClient(this.pxeURL);
    const encryptionPrivateKey = deriveMasterIncomingViewingSecretKey(secretKey);
    this.accountContract = new SingleKeyAccountContract(encryptionPrivateKey);
    this.account = new AccountManager(this.pxe, this.secretKey, this.accountContract);
  }

  async getWallet() {
    // taking advantage that register is no-op if already registered
    return await this.account.register();
  }
  async deployDegenScoreContract() {
    const wallet = await this.getWallet();
    const contract = await DegenScoreContractArtifact.deploy(this.pxe, wallet).send().deployed();
    return contract;
  }
}

export const deployerEnv = new PrivateEnv(SECRET_KEY, process.env.PXE_URL || 'http://localhost:8080');

const IGNORE_FUNCTIONS = ['constructor', 'compute_note_hash_and_optionally_a_nullifier'];
export const filteredInterface = DegenScoreContractArtifact.functions.filter(f => !IGNORE_FUNCTIONS.includes(f.name));
