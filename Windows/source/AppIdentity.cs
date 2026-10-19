using System.Reflection;

namespace CampusConnect;

/// <summary>
/// 从可执行文件名自动派生应用标识。让同一套源码以不同名称发布时，
/// 配置目录、进程互斥、开机自启注册表值等全部自动隔离。
///
///   CampusConnect.exe   → Local\CampusConnect.Windows,   %LOCALAPPDATA%\CampusConnect\
///   自动登录.exe         → Local\自动登录.Windows,         %LOCALAPPDATA%\自动登录\
/// </summary>
internal static class AppIdentity
{
    private static readonly string _name =
        Path.GetFileNameWithoutExtension(Environment.ProcessPath
            ?? Assembly.GetExecutingAssembly().Location)
        ?? "CampusConnect";

    /// <summary>应用主名（即 exe 文件名，不带扩展名）。</summary>
    public static string Name => _name;

    /// <summary>Windows 专属标识（注册表值、互斥体后缀）。</summary>
    public static string WindowsTag => _name + ".Windows";

    /// <summary>互斥体全名。</summary>
    public static string MutexName => "Local\\" + WindowsTag;
}
