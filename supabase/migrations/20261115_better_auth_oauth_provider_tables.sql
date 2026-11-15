-- Better Auth OAuthProvider database models sourced from better-auth/better-auth tag v1.7.21.
-- Adds isolated tables only; existing user data is not changed.
begin;
create table if not exists mastersite_feelings_auth."oauthClient" (
  "id" text primary key,
  "clientId" text not null unique,
  "clientSecret" text,
  "clientDiscoveryId" text,
  "disabled" boolean default false,
  "skipConsent" boolean,
  "enableEndSession" boolean,
  "subjectType" text,
  "scopes" text[],
  "clientCredentialsScopes" text[],
  "userId" text,
  "createdAt" timestamptz,
  "updatedAt" timestamptz,
  "name" text,
  "uri" text,
  "icon" text,
  "contacts" text[],
  "tos" text,
  "policy" text,
  "softwareId" text,
  "softwareVersion" text,
  "softwareStatement" text,
  "redirectUris" text[] not null,
  "postLogoutRedirectUris" text[],
  "backchannelLogoutUri" text,
  "backchannelLogoutSessionRequired" boolean,
  "tokenEndpointAuthMethod" text,
  "applicationType" text,
  "jwks" text,
  "jwksUri" text,
  "grantTypes" text[],
  "responseTypes" text[],
  "requirePKCE" boolean,
  "dpopBoundAccessTokens" boolean default false,
  "referenceId" text,
  "metadata" jsonb
);
alter table mastersite_feelings_auth."oauthClient" enable row level security;
revoke all on mastersite_feelings_auth."oauthClient" from PUBLIC, anon, authenticated, service_role;
create table if not exists mastersite_feelings_auth."oauthResource" (
  "id" text primary key,
  "identifier" text not null unique,
  "name" text not null,
  "accessTokenTtl" integer,
  "refreshTokenTtl" integer,
  "signingAlgorithm" text,
  "signingKeyId" text,
  "allowedScopes" text[],
  "customClaims" jsonb,
  "dpopBoundAccessTokensRequired" boolean default false,
  "disabled" boolean default false,
  "createdAt" timestamptz,
  "updatedAt" timestamptz,
  "policyVersion" integer default 1,
  "metadata" jsonb
);
alter table mastersite_feelings_auth."oauthResource" enable row level security;
revoke all on mastersite_feelings_auth."oauthResource" from PUBLIC, anon, authenticated, service_role;
create table if not exists mastersite_feelings_auth."oauthClientResource" (
  "id" text primary key,
  "clientId" text not null,
  "resourceId" text not null,
  "metadata" jsonb,
  "createdAt" timestamptz
);
alter table mastersite_feelings_auth."oauthClientResource" enable row level security;
revoke all on mastersite_feelings_auth."oauthClientResource" from PUBLIC, anon, authenticated, service_role;
create table if not exists mastersite_feelings_auth."oauthRefreshToken" (
  "id" text primary key,
  "token" text not null unique,
  "clientId" text not null,
  "sessionId" text,
  "userId" text not null,
  "referenceId" text,
  "authorizationCodeId" text,
  "resources" text[],
  "requestedUserInfoClaims" text[],
  "expiresAt" timestamptz,
  "createdAt" timestamptz,
  "revoked" timestamptz,
  "rotatedAt" timestamptz,
  "rotationReplayResponse" text,
  "rotationReplayExpiresAt" timestamptz,
  "authTime" timestamptz,
  "confirmation" jsonb,
  "scopes" text[] not null
);
alter table mastersite_feelings_auth."oauthRefreshToken" enable row level security;
revoke all on mastersite_feelings_auth."oauthRefreshToken" from PUBLIC, anon, authenticated, service_role;
create table if not exists mastersite_feelings_auth."oauthAccessToken" (
  "id" text primary key,
  "token" text unique,
  "clientId" text not null,
  "sessionId" text,
  "userId" text,
  "referenceId" text,
  "authorizationCodeId" text,
  "resources" text[],
  "requestedUserInfoClaims" text[],
  "refreshId" text,
  "expiresAt" timestamptz,
  "createdAt" timestamptz,
  "revoked" timestamptz,
  "confirmation" jsonb,
  "scopes" text[] not null
);
alter table mastersite_feelings_auth."oauthAccessToken" enable row level security;
revoke all on mastersite_feelings_auth."oauthAccessToken" from PUBLIC, anon, authenticated, service_role;
create table if not exists mastersite_feelings_auth."oauthConsent" (
  "id" text primary key,
  "clientId" text not null,
  "userId" text,
  "referenceId" text,
  "resources" text[],
  "requestedUserInfoClaims" text[],
  "scopes" text[] not null,
  "createdAt" timestamptz,
  "updatedAt" timestamptz
);
alter table mastersite_feelings_auth."oauthConsent" enable row level security;
revoke all on mastersite_feelings_auth."oauthConsent" from PUBLIC, anon, authenticated, service_role;
create table if not exists mastersite_feelings_auth."oauthClientAssertion" (
  "id" text primary key,
  "expiresAt" timestamptz not null
);
alter table mastersite_feelings_auth."oauthClientAssertion" enable row level security;
revoke all on mastersite_feelings_auth."oauthClientAssertion" from PUBLIC, anon, authenticated, service_role;
create unique index if not exists "mastersite_feelings_auth_oauth_client_resource_uidx" on mastersite_feelings_auth."oauthClientResource" ("clientId","resourceId");
create table if not exists mastersite_pullrates_auth."oauthClient" (
  "id" text primary key,
  "clientId" text not null unique,
  "clientSecret" text,
  "clientDiscoveryId" text,
  "disabled" boolean default false,
  "skipConsent" boolean,
  "enableEndSession" boolean,
  "subjectType" text,
  "scopes" text[],
  "clientCredentialsScopes" text[],
  "userId" text,
  "createdAt" timestamptz,
  "updatedAt" timestamptz,
  "name" text,
  "uri" text,
  "icon" text,
  "contacts" text[],
  "tos" text,
  "policy" text,
  "softwareId" text,
  "softwareVersion" text,
  "softwareStatement" text,
  "redirectUris" text[] not null,
  "postLogoutRedirectUris" text[],
  "backchannelLogoutUri" text,
  "backchannelLogoutSessionRequired" boolean,
  "tokenEndpointAuthMethod" text,
  "applicationType" text,
  "jwks" text,
  "jwksUri" text,
  "grantTypes" text[],
  "responseTypes" text[],
  "requirePKCE" boolean,
  "dpopBoundAccessTokens" boolean default false,
  "referenceId" text,
  "metadata" jsonb
);
alter table mastersite_pullrates_auth."oauthClient" enable row level security;
revoke all on mastersite_pullrates_auth."oauthClient" from PUBLIC, anon, authenticated, service_role;
create table if not exists mastersite_pullrates_auth."oauthResource" (
  "id" text primary key,
  "identifier" text not null unique,
  "name" text not null,
  "accessTokenTtl" integer,
  "refreshTokenTtl" integer,
  "signingAlgorithm" text,
  "signingKeyId" text,
  "allowedScopes" text[],
  "customClaims" jsonb,
  "dpopBoundAccessTokensRequired" boolean default false,
  "disabled" boolean default false,
  "createdAt" timestamptz,
  "updatedAt" timestamptz,
  "policyVersion" integer default 1,
  "metadata" jsonb
);
alter table mastersite_pullrates_auth."oauthResource" enable row level security;
revoke all on mastersite_pullrates_auth."oauthResource" from PUBLIC, anon, authenticated, service_role;
create table if not exists mastersite_pullrates_auth."oauthClientResource" (
  "id" text primary key,
  "clientId" text not null,
  "resourceId" text not null,
  "metadata" jsonb,
  "createdAt" timestamptz
);
alter table mastersite_pullrates_auth."oauthClientResource" enable row level security;
revoke all on mastersite_pullrates_auth."oauthClientResource" from PUBLIC, anon, authenticated, service_role;
create table if not exists mastersite_pullrates_auth."oauthRefreshToken" (
  "id" text primary key,
  "token" text not null unique,
  "clientId" text not null,
  "sessionId" text,
  "userId" text not null,
  "referenceId" text,
  "authorizationCodeId" text,
  "resources" text[],
  "requestedUserInfoClaims" text[],
  "expiresAt" timestamptz,
  "createdAt" timestamptz,
  "revoked" timestamptz,
  "rotatedAt" timestamptz,
  "rotationReplayResponse" text,
  "rotationReplayExpiresAt" timestamptz,
  "authTime" timestamptz,
  "confirmation" jsonb,
  "scopes" text[] not null
);
alter table mastersite_pullrates_auth."oauthRefreshToken" enable row level security;
revoke all on mastersite_pullrates_auth."oauthRefreshToken" from PUBLIC, anon, authenticated, service_role;
create table if not exists mastersite_pullrates_auth."oauthAccessToken" (
  "id" text primary key,
  "token" text unique,
  "clientId" text not null,
  "sessionId" text,
  "userId" text,
  "referenceId" text,
  "authorizationCodeId" text,
  "resources" text[],
  "requestedUserInfoClaims" text[],
  "refreshId" text,
  "expiresAt" timestamptz,
  "createdAt" timestamptz,
  "revoked" timestamptz,
  "confirmation" jsonb,
  "scopes" text[] not null
);
alter table mastersite_pullrates_auth."oauthAccessToken" enable row level security;
revoke all on mastersite_pullrates_auth."oauthAccessToken" from PUBLIC, anon, authenticated, service_role;
create table if not exists mastersite_pullrates_auth."oauthConsent" (
  "id" text primary key,
  "clientId" text not null,
  "userId" text,
  "referenceId" text,
  "resources" text[],
  "requestedUserInfoClaims" text[],
  "scopes" text[] not null,
  "createdAt" timestamptz,
  "updatedAt" timestamptz
);
alter table mastersite_pullrates_auth."oauthConsent" enable row level security;
revoke all on mastersite_pullrates_auth."oauthConsent" from PUBLIC, anon, authenticated, service_role;
create table if not exists mastersite_pullrates_auth."oauthClientAssertion" (
  "id" text primary key,
  "expiresAt" timestamptz not null
);
alter table mastersite_pullrates_auth."oauthClientAssertion" enable row level security;
revoke all on mastersite_pullrates_auth."oauthClientAssertion" from PUBLIC, anon, authenticated, service_role;
create unique index if not exists "mastersite_pullrates_auth_oauth_client_resource_uidx" on mastersite_pullrates_auth."oauthClientResource" ("clientId","resourceId");
commit;
