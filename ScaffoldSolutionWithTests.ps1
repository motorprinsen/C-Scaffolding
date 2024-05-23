param (
    [string]$Name = "MyNewProduct"
)

# Define project names based on the provided name
$SolutionName = "${Name}Solution"
$ApiProjectName = "${Name}.Api"
$CoreProjectName = "${Name}.Core"
$InfrastructureProjectName = "${Name}.Infrastructure"
$TestProjectName = "${Name}.Tests"

# Create the solution directory
New-Item -Path . -Name $SolutionName -ItemType Directory
Set-Location -Path $SolutionName

# Create the solution file
dotnet new sln -n $SolutionName

# Create the projects
dotnet new webapi -n $ApiProjectName
dotnet new classlib -n $CoreProjectName
dotnet new classlib -n $InfrastructureProjectName
dotnet new xunit -n $TestProjectName

# Add the projects to the solution
dotnet sln add $ApiProjectName/$ApiProjectName.csproj
dotnet sln add $CoreProjectName/$CoreProjectName.csproj
dotnet sln add $InfrastructureProjectName/$InfrastructureProjectName.csproj
dotnet sln add $TestProjectName/$TestProjectName.csproj

# Add project references
dotnet add $ApiProjectName/$ApiProjectName.csproj reference $CoreProjectName/$CoreProjectName.csproj
dotnet add $ApiProjectName/$ApiProjectName.csproj reference $InfrastructureProjectName/$InfrastructureProjectName.csproj
dotnet add $InfrastructureProjectName/$InfrastructureProjectName.csproj reference $CoreProjectName/$CoreProjectName.csproj
dotnet add $TestProjectName/$TestProjectName.csproj reference $ApiProjectName/$ApiProjectName.csproj
dotnet add $TestProjectName/$TestProjectName.csproj reference $CoreProjectName/$CoreProjectName.csproj
dotnet add $TestProjectName/$TestProjectName.csproj reference $InfrastructureProjectName/$InfrastructureProjectName.csproj

# Add necessary packages to the projects
dotnet add $ApiProjectName/$ApiProjectName.csproj package Microsoft.EntityFrameworkCore
dotnet add $ApiProjectName/$ApiProjectName.csproj package Microsoft.EntityFrameworkCore.SqlServer
dotnet add $ApiProjectName/$ApiProjectName.csproj package Microsoft.EntityFrameworkCore.Tools
dotnet add $ApiProjectName/$ApiProjectName.csproj package Microsoft.Extensions.Logging
dotnet add $ApiProjectName/$ApiProjectName.csproj package Microsoft.Extensions.Logging.Console

dotnet add $CoreProjectName/$CoreProjectName.csproj package Microsoft.Extensions.DependencyInjection.Abstractions

dotnet add $InfrastructureProjectName/$InfrastructureProjectName.csproj package Microsoft.EntityFrameworkCore
dotnet add $InfrastructureProjectName/$InfrastructureProjectName.csproj package Microsoft.EntityFrameworkCore.SqlServer

dotnet add $TestProjectName/$TestProjectName.csproj package Microsoft.EntityFrameworkCore.InMemory
dotnet add $TestProjectName/$TestProjectName.csproj package Moq

# Create basic directory structure for Core project
New-Item -Path $CoreProjectName -Name "Entities" -ItemType Directory
New-Item -Path $CoreProjectName -Name "Interfaces" -ItemType Directory
New-Item -Path $CoreProjectName -Name "Services" -ItemType Directory

# Create basic directory structure for Infrastructure project
New-Item -Path $InfrastructureProjectName -Name "Data" -ItemType Directory
New-Item -Path $InfrastructureProjectName -Name "Repositories" -ItemType Directory

# Add a DbContext class to the Infrastructure project
$dbContextPath = "$InfrastructureProjectName/Data/ApplicationDbContext.cs"
@"
using Microsoft.EntityFrameworkCore;
using $CoreProjectName.Entities;

namespace $InfrastructureProjectName.Data
{
    public class ApplicationDbContext : DbContext
    {
        public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options)
            : base(options)
        {
        }

        public DbSet<MyEntity> MyEntities { get; set; }
    }
}
"@ > $dbContextPath

# Add a simple entity to the Core project
$entityPath = "$CoreProjectName/Entities/MyEntity.cs"
@"
namespace $CoreProjectName.Entities
{
    public class MyEntity
    {
        public int Id { get; set; }
        public string Name { get; set; }
    }
}
"@ > $entityPath

# Add repository interface to the Core project
$repositoryInterfacePath = "$CoreProjectName/Interfaces/IRepository.cs"
@"
using System.Collections.Generic;
using System.Threading.Tasks;

namespace $CoreProjectName.Interfaces
{
    public interface IRepository<T> where T : class
    {
        Task<IEnumerable<T>> GetAllAsync();
        Task<T> GetByIdAsync(int id);
        Task AddAsync(T entity);
        Task UpdateAsync(T entity);
        Task DeleteAsync(int id);
    }
}
"@ > $repositoryInterfacePath

# Add repository implementation to the Infrastructure project
$repositoryImplementationPath = "$InfrastructureProjectName/Repositories/Repository.cs"
@"
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using $CoreProjectName.Interfaces;
using $InfrastructureProjectName.Data;

namespace $InfrastructureProjectName.Repositories
{
    public class Repository<T> : IRepository<T> where T : class
    {
        private readonly ApplicationDbContext _context;

        public Repository(ApplicationDbContext context)
        {
            _context = context;
        }

        public async Task<IEnumerable<T>> GetAllAsync()
        {
            return await _context.Set<T>().ToListAsync();
        }

        public async Task<T> GetByIdAsync(int id)
        {
            return await _context.Set<T>().FindAsync(id);
        }

        public async Task AddAsync(T entity)
        {
            await _context.Set<T>().AddAsync(entity);
            await _context.SaveChangesAsync();
        }

        public async Task UpdateAsync(T entity)
        {
            _context.Set<T>().Update(entity);
            await _context.SaveChangesAsync();
        }

        public async Task DeleteAsync(int id)
        {
            var entity = await _context.Set<T>().FindAsync(id);
            _context.Set<T>().Remove(entity);
            await _context.SaveChangesAsync();
        }
    }
}
"@ > $repositoryImplementationPath

# Add basic configuration to the API project's Startup.cs
$startupPath = "$ApiProjectName/Startup.cs"
@"
using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using $InfrastructureProjectName.Data;
using $CoreProjectName.Interfaces;
using $InfrastructureProjectName.Repositories;

namespace $ApiProjectName
{
    public class Startup
    {
        public Startup(IConfiguration configuration)
        {
            Configuration = configuration;
        }

        public IConfiguration Configuration { get; }

        public void ConfigureServices(IServiceCollection services)
        {
            services.AddDbContext<ApplicationDbContext>(options =>
                options.UseSqlServer(Configuration.GetConnectionString(""DefaultConnection"")));

            services.AddScoped(typeof(IRepository<>), typeof(Repository<>));

            services.AddControllers();
        }

        public void Configure(IApplicationBuilder app, IWebHostEnvironment env)
        {
            if (env.IsDevelopment())
            {
                app.UseDeveloperExceptionPage();
            }

            app.UseHttpsRedirection();

            app.UseRouting();

            app.UseAuthorization();

            app.UseEndpoints(endpoints =>
            {
                endpoints.MapControllers();
            });
        }
    }
}
"@ > $startupPath

# Create an appsettings.json file with the default connection string
$appSettingsPath = "$ApiProjectName/appsettings.json"
@"
{
  ""ConnectionStrings"": {
    ""DefaultConnection"": ""Server=(localdb)\\mssqllocaldb;Database=$SolutionName;Trusted_Connection=True;MultipleActiveResultSets=true""
  },
  ""Logging"": {
    ""LogLevel"": {
      ""Default"": ""Information"",
      ""Microsoft"": ""Warning"",
      ""Microsoft.Hosting.Lifetime"": ""Information""
    }
  },
  ""AllowedHosts"": ""*""
}
"@ > $appSettingsPath

# Create a sample unit test in the Test project
$testClassPath = "$TestProjectName/UnitTest1.cs"
@"
using Xunit;
using $CoreProjectName.Entities;
using $CoreProjectName.Interfaces;
using $InfrastructureProjectName.Repositories;
using Moq;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace $TestProjectName
{
    public class RepositoryTests
    {
        private readonly Mock<IRepository<MyEntity>> _mockRepository;

        public RepositoryTests()
        {
            _mockRepository = new Mock<IRepository<MyEntity>>();
        }

        [Fact]
        public async Task GetAllAsync_ShouldReturnAllEntities()
        {
            // Arrange
            var entities = new List<MyEntity>
            {
                new MyEntity { Id = 1, Name = ""Entity1"" },
                new MyEntity { Id = 2, Name = ""Entity2"" }
            };

            _mockRepository.Setup(repo => repo.GetAllAsync()).ReturnsAsync(entities);

            // Act
            var result = await _mockRepository.Object.GetAllAsync();

            // Assert
            Assert.Equal(2, result.Count());
        }
    }
}
"@ > $testClassPath

Write-Host "Solution scaffolded successfully."
