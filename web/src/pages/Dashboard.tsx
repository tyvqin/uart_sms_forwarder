import {useEffect, useState} from 'react';
import {Globe, MessageSquare, Signal, TrendingUp} from 'lucide-react';
import {useQuery} from '@tanstack/react-query';
import {getStats} from '../api/messages';
import type {DeviceStatus, Stats} from '../api/types';
import {getDevices, getStatus} from '@/api/serial.ts';
import {StatCard} from '@/components/StatsCard.tsx';
import {Select, SelectContent, SelectItem, SelectTrigger, SelectValue} from '@/components/ui/select';

export default function Dashboard() {
    const [stats, setStats] = useState<Stats | null>(null);
    const [loading, setLoading] = useState(true);
    const [selectedDeviceId, setSelectedDeviceId] = useState('');

    useEffect(() => {
        loadStats();
        const interval = setInterval(loadStats, 30000);
        return () => clearInterval(interval);
    }, []);

    const loadStats = async () => {
        try {
            setStats(await getStats());
        } finally {
            setLoading(false);
        }
    };

    const {data: devices = []} = useQuery({
        queryKey: ['serialDevices'],
        queryFn: getDevices,
        refetchInterval: 10000,
    });

    useEffect(() => {
        if (!selectedDeviceId && devices.length > 0) setSelectedDeviceId(devices[0].id);
    }, [devices, selectedDeviceId]);

    const {data: deviceStatus} = useQuery<DeviceStatus>({
        queryKey: ['deviceStatus', selectedDeviceId],
        queryFn: async () => await getStatus(selectedDeviceId) as DeviceStatus,
        enabled: !!selectedDeviceId,
        refetchInterval: 10000,
    });

    const getSignalPercentage = () => {
        if (!deviceStatus?.mobile?.rsrp) return 0;
        return Math.max(0, Math.min(100, Math.round(((deviceStatus.mobile.rsrp + 140) / 96) * 100)));
    };

    const getSignalDescription = () => {
        const rsrp = deviceStatus?.mobile?.rsrp;
        if (!rsrp) return 'N/A';
        if (rsrp >= -80) return '优秀';
        if (rsrp >= -90) return '良好';
        if (rsrp >= -100) return '一般';
        if (rsrp >= -110) return '较差';
        return '很差';
    };

    if (loading) return <div className="flex justify-center items-center h-64"><div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div></div>;

    return (
        <div>
            <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
                <h1 className="text-2xl font-bold text-gray-900">统计面板</h1>
                {devices.length > 0 && (
                    <Select value={selectedDeviceId} onValueChange={setSelectedDeviceId}>
                        <SelectTrigger className="w-full sm:w-[260px]"><SelectValue placeholder="选择 SIM 卡"/></SelectTrigger>
                        <SelectContent>
                            {devices.map((device) => (
                                <SelectItem key={device.id} value={device.id}>
                                    {device.name || device.id.toUpperCase()} · {device.connected ? '已连接' : '未连接'}
                                </SelectItem>
                            ))}
                        </SelectContent>
                    </Select>
                )}
            </div>

            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6">
                <StatCard label="信号强度" value={getSignalPercentage()} unit="%" icon={Signal} colorClass="bg-green-100 text-green-600" subValue={`${getSignalDescription()} · RSRP: ${deviceStatus?.mobile?.rsrp || 'N/A'} dBm`}/>
                <StatCard label="当前运营商" value={deviceStatus?.mobile?.operator || '未知'} icon={Globe} colorClass="bg-blue-100 text-blue-600" subValue={deviceStatus?.mobile?.number ? `号码: ${deviceStatus.mobile.number}` : '号码未提供'}/>
                <StatCard label="总短信数" value={stats?.totalCount || 0} icon={MessageSquare} colorClass="bg-green-100 text-green-600"/>
                <StatCard label="今日短信" value={stats?.todayCount || 0} icon={TrendingUp} colorClass="bg-purple-100 text-purple-600"/>
            </div>
        </div>
    );
}
