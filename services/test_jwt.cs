using System;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;

class Program {
    static void Main() {
        var userId = Guid.NewGuid();
        var handler = new JwtSecurityTokenHandler();
        var token = new JwtSecurityToken(claims: new[] {
            new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            new Claim("sub", userId.ToString())
        });
        Console.WriteLine(handler.WriteToken(token));
    }
}
