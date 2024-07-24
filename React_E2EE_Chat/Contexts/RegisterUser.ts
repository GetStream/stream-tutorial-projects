import SealdSDK from '@seald-io/sdk';
import { SignJWT } from 'jose';
import { v4 as uuidv4 } from 'uuid';
import { Buffer } from 'buffer';

export async function registerUser(
    seald: SealdSDK,
    userId: string,
    password: string
  ): Promise<void> {
    'use server';
    const signUpJWT = await createSignupJWT();
    await seald.initiateIdentity({
      signupJWT: signUpJWT,
    });
    await seald.ssksPassword.saveIdentity({ userId, password });
}

async function createSignupJWT() {
    'use server';

    const jwtSecret = import.meta.env.VITE_JWT_SECRET;
    const jwtSecretId = import.meta.env.VITE_JWT_SECRET_ID;
    // console.log('jwtSecret', jwtSecret);
    // console.log('jwtSecretId', jwtSecretId);

    const token = new SignJWT({
        iss: jwtSecretId,
        jti: uuidv4(), // So the JWT is only usable once. The `random` generates a random string, with enough entropy to never repeat : a UUIDv4 would be a good choice.
        iat: Math.floor(Date.now() / 1000), // JWT valid only for 10 minutes. `Date.now()` returns the timestamp in milliseconds, this needs it in seconds.
        scopes: [3], // PERMISSION_JOIN_TEAM
        join_team: true,
    }).setProtectedHeader({ alg: 'HS256' });

    const signupJWT = await token.sign(Buffer.from(jwtSecret, 'ascii'));
    return signupJWT;
}
