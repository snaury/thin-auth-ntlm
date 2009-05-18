= NTLM Authentication for Thin

Allows you to force NTLM authentication on Thin TCP servers.

= Using thin-auth-ntlm

Just start your thin server using NTLMTcpServer backend:

  thin -r thin-auth-ntlm -b Thin::Backends::NTLMTcpServer start

Remote username will be available as request.remote_user.
