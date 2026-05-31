import {Link, Outlet, useLocation, useNavigate} from 'react-router-dom';
import {Bell, Clock, LayoutDashboard, LogOut, MessageSquare, Smartphone} from 'lucide-react';
import {Button} from "@/components/ui/button.tsx";
import {useQuery} from "@tanstack/react-query";
import {getVersion} from "@/api/property.ts";
import {getDevices} from "@/api/serial.ts";
import type {SerialDeviceInfo} from "@/api/types.ts";
import {cn} from "@/lib/utils.ts";
import {toast} from 'sonner';

export default function Layout() {
    const location = useLocation();
    const navigate = useNavigate();

    const navigation = [
        {name: '统计', href: '/', icon: LayoutDashboard},
        {name: '短信', href: '/messages', icon: MessageSquare},
        {name: '串口', href: '/serial', icon: Smartphone},
        {name: '通知', href: '/notifications', icon: Bell},
        {name: '计划', href: '/scheduled-tasks', icon: Clock},
    ];

    const versionQuery = useQuery({queryKey: ['version'], queryFn: getVersion});
    const {data: devices = []} = useQuery<SerialDeviceInfo[]>({
        queryKey: ['serialDevices'],
        queryFn: getDevices,
        refetchInterval: 10000,
    });

    const onlineCount = devices.filter((device) => device.connected).length;
    const firstOnline = devices.find((device) => device.connected);
    const totalCount = devices.length;
    const onlineText = totalCount > 1 ? `${onlineCount}/${totalCount} 在线` : (onlineCount ? '在线' : '离线');
    const shortDevice = firstOnline ? (firstOnline.name || firstOnline.id.toUpperCase()) : '无设备';

    const isActive = (path: string) => path === '/' ? location.pathname === '/' : location.pathname.startsWith(path);

    const handleLogout = () => {
        localStorage.removeItem('token');
        localStorage.removeItem('username');
        toast.success('已退出登录');
        navigate('/login');
    };

    return (
        <div className="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 flex flex-col">
            <nav className="bg-white/95 backdrop-blur-sm border-b border-gray-200 sticky top-0 z-50">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
                    <div className="flex justify-between h-16">
                        <div className="flex items-center space-x-4 lg:space-x-8">
                            <div className="flex items-center space-x-2 lg:space-x-3 flex-shrink-0">
                                <img src="/logo.png" alt="Jay's SMS" className="w-6 h-6"/>
                                <div className="hidden sm:flex flex-col">
                                    <h1 className="text-base lg:text-lg font-bold leading-tight bg-gradient-to-r from-gray-900 to-gray-700 bg-clip-text text-transparent">
                                        Jay's SMS
                                    </h1>
                                </div>
                            </div>

                            <div className="hidden md:flex items-center space-x-1">
                                {navigation.map((item) => {
                                    const Icon = item.icon;
                                    const active = isActive(item.href);
                                    return (
                                        <Link
                                            key={item.name}
                                            to={item.href}
                                            className={`px-2 lg:px-3 xl:px-4 py-2 flex items-center space-x-1 lg:space-x-2 rounded-lg transition-all duration-200 font-medium text-xs lg:text-sm whitespace-nowrap ${
                                                active ? 'bg-blue-50 text-blue-600' : 'text-gray-500 hover:bg-gray-100 hover:text-gray-900'
                                            }`}
                                        >
                                            <Icon className="w-4 h-4 flex-shrink-0"/>
                                            <span className="hidden lg:inline">{item.name}</span>
                                        </Link>
                                    );
                                })}
                            </div>
                        </div>

                        <div className="hidden md:flex items-center space-x-2 lg:space-x-4">
                            <div className="min-w-0 rounded-lg border border-gray-100 bg-gray-50 px-3 py-1.5">
                                <div className="flex items-center gap-2">
                                    <div className={cn("w-2 h-2 rounded-full", onlineCount > 0 ? 'bg-green-500' : 'bg-red-500')}/>
                                    <div className="text-xs font-semibold text-gray-700">{onlineText}</div>
                                </div>
                                <div className="max-w-24 truncate text-[10px] text-gray-400 mt-0.5">{shortDevice}</div>
                            </div>

                            <Button variant="ghost" size="sm" onClick={handleLogout} className="text-gray-600 hover:text-gray-900 hover:bg-gray-100 rounded-lg">
                                <LogOut className="w-4 h-4 mr-2"/>
                                登出
                            </Button>
                        </div>

                        <div className="flex md:hidden items-center space-x-2">
                            <div className={cn("flex items-center space-x-1 px-2 py-1 rounded-lg", onlineCount > 0 ? 'bg-green-50 text-green-700' : 'bg-red-50 text-red-700')}>
                                <div className={cn("w-2 h-2 rounded-full", onlineCount > 0 ? 'bg-green-500' : 'bg-red-500')}/>
                                <span className="text-xs font-medium">{onlineText}</span>
                            </div>
                            <Button variant="ghost" size="sm" onClick={handleLogout} className="text-gray-600">
                                <LogOut className="w-4 h-4"/>
                            </Button>
                        </div>
                    </div>
                </div>

                <div className="md:hidden border-t border-gray-200 bg-white">
                    <div className="flex justify-around py-2">
                        {navigation.map((item) => {
                            const Icon = item.icon;
                            const active = isActive(item.href);
                            return (
                                <Link key={item.name} to={item.href} className={`flex flex-col items-center px-3 py-2 text-xs font-medium transition-all duration-200 ${active ? 'text-blue-600' : 'text-gray-500'}`}>
                                    <Icon className={`w-6 h-6 mb-1 transition-transform ${active ? 'scale-110' : ''}`}/>
                                    <span className={active ? 'font-semibold' : ''}>{item.name}</span>
                                </Link>
                            );
                        })}
                    </div>
                </div>
            </nav>

            <main className="flex-1 max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6 w-full">
                <Outlet/>
            </main>

            <footer className="bg-white/80 backdrop-blur-sm border-t border-gray-200 mt-auto">
                <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-4">
                    <div className="text-center text-xs text-gray-500">
                        Jay's SMS · 版本 {versionQuery.data?.version || 'dev'}
                    </div>
                </div>
            </footer>
        </div>
    );
}
