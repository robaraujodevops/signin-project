import { createContext, ReactChildren, useEffect, useState }  from "react";
import { recoverUserInformation, signInRequest } from "../services/auth";
import { api } from "../services/api";
import Router from "next/router"

import { setCookie, parseCookies } from "nookies";

type User = {
  name: string;
  email: string;
  avatar_url: string;
}

type SignInData = {
  email: string;
  password: string;
}

type AuthContextType = {
  isAuthenticated: boolean;
  user: User | null;
  signIn: (data: SignInData) => Promise<void>
 }

export const AuthContext = createContext({} as AuthContextType)

export function AuthProvider({ children }: any) {
  const [user, setUser] = useState<User | null>(null);
  const isAuthenticated = !!user;

  useEffect(() => {
    const { 'signin.token': token } = parseCookies()

    if (token) {
      recoverUserInformation().then(response => {
        setUser(response.user)
      })
    }
  }, [])

  async function signIn({ email, password }: SignInData) {
    const { token, user } = await signInRequest({
      email,
      password
    })

    setCookie(undefined, 'signin.token', token, {
      maxAge: 60 * 60 * 1,
    })

    if (!token) api.defaults.headers['Authorizarion'] = `Bearer ${token}`;

    setUser(user)

    Router.push('/dashboard')
  }

  return (
    <AuthContext.Provider value={{ user, isAuthenticated, signIn }}>
      {children}
    </AuthContext.Provider>
  )
}
