import {useEffect, useMemo, useState} from 'react';
import {useMutation, useQuery, useQueryClient} from '@tanstack/react-query';
import {Bell, Loader2, PhoneCall, Plus, Radio, Save, TestTube, Trash2} from 'lucide-react';
import {toast} from 'sonner';

import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Textarea} from '@/components/ui/textarea';
import {Card, CardContent, CardDescription, CardHeader, CardTitle} from '@/components/ui/card';
import {getDevices} from '@/api/serial.ts';
import {
    defaultStatusPushConfig,
    getCallNotificationConfig,
    getNotificationChannels,
    getStatusPushConfig,
    type CallNotificationConfig,
    type NotificationChannel,
    saveCallNotificationConfig,
    saveNotificationChannels,
    saveStatusPushConfig,
    type StatusPushConfig,
    testNotificationChannel,
    testStatusPush,
} from '@/api/property.ts';

type ChannelType = NotificationChannel['type'];

const CHANNEL_TYPES: Array<{type: ChannelType; label: string; description: string}> = [
    {type: 'dingtalk', label: '钉钉', description: '钉钉自定义机器人'},
    {type: 'feishu', label: '飞书', description: '飞书自定义机器人'},
    {type: 'wecom', label: '企业微信', description: '企业微信群机器人'},
    {type: 'webhook', label: 'Webhook', description: '自定义 HTTP 推送'},
    {type: 'email', label: '邮件', description: 'SMTP 邮件推送'},
    {type: 'telegram', label: 'Telegram', description: 'Telegram Bot 推送'},
];

const DEFAULT_WEBHOOK_BODY = '{"from":"{{from}}","content":"{{content}}","deviceId":"{{deviceId}}","deviceName":"{{deviceName}}","timestamp":"{{timestamp}}"}';

function channelLabel(type: ChannelType) {
    return CHANNEL_TYPES.find((item) => item.type === type)?.label || type;
}

function defaultConfig(type: ChannelType): Record<string, any> {
    switch (type) {
        case 'webhook':
            return {url: '', method: 'POST', contentType: 'application/json; charset=utf-8', headers: {}, body: DEFAULT_WEBHOOK_BODY};
        case 'email':
            return {smtpHost: '', smtpPort: '587', username: '', password: '', from: '', to: '', subject: 'Jay SMS - {{from}}'};
        case 'telegram':
            return {apiToken: '', userid: '', proxyEnabled: false, proxyUrl: '', proxyUsername: '', proxyPassword: ''};
        default:
            return {secretKey: '', signSecret: ''};
    }
}

function makeChannel(type: ChannelType): NotificationChannel {
    const suffix = Date.now().toString(36);
    return {id: `${type}-${suffix}`, name: channelLabel(type), type, enabled: true, deviceIds: [], config: defaultConfig(type)};
}

function withClientDefaults(channel: NotificationChannel, index: number): NotificationChannel {
    return {
        ...channel,
        id: channel.id || `${channel.type}-${index + 1}`,
        name: channel.name || channelLabel(channel.type),
        deviceIds: channel.deviceIds || [],
        config: {...defaultConfig(channel.type), ...(channel.config || {})},
    };
}

function hasAnyConfigValue(config: Record<string, any>) {
    return Object.values(config).some((value) => {
        if (typeof value === 'string') return value.trim() !== '';
        if (Array.isArray(value)) return value.length > 0;
        if (value && typeof value === 'object') return Object.keys(value).length > 0;
        return Boolean(value);
    });
}

function normalizeForSave(channels: NotificationChannel[]) {
    return channels
        .map((channel, index) => withClientDefaults(channel, index))
        .filter((channel) => channel.enabled || hasAnyConfigValue(channel.config || {}))
        .map((channel) => ({
            ...channel,
            name: (channel.name || channelLabel(channel.type)).trim(),
            deviceIds: Array.from(new Set((channel.deviceIds || []).map((id) => id.trim()).filter(Boolean))),
        }));
}

function normalizeStatusConfig(config: StatusPushConfig): StatusPushConfig {
    const times = Array.from(new Set((config.times || []).map((time) => time.trim()).filter(Boolean))).sort();
    return {
        ...config,
        times: times.length ? times : ['09:00'],
        channelIds: Array.from(new Set(config.channelIds || [])),
    };
}

export default function NotificationChannels() {
    const queryClient = useQueryClient();
    const [draft, setDraft] = useState<NotificationChannel[]>([]);
    const [newType, setNewType] = useState<ChannelType>('dingtalk');
    const [statusDraft, setStatusDraft] = useState<StatusPushConfig>(defaultStatusPushConfig());
    const [callDraft, setCallDraft] = useState<CallNotificationConfig>({enabled: false, channelIds: []});

    const {data: channels = [], isLoading} = useQuery({queryKey: ['notificationChannels'], queryFn: getNotificationChannels});
    const {data: devices = []} = useQuery({queryKey: ['serialDevices'], queryFn: getDevices, refetchInterval: 10000});
    const {data: statusPushConfig} = useQuery({queryKey: ['statusPushConfig'], queryFn: getStatusPushConfig});
    const {data: callConfig} = useQuery({queryKey: ['callNotificationConfig'], queryFn: getCallNotificationConfig});

    useEffect(() => setDraft(channels.map(withClientDefaults)), [channels]);
    useEffect(() => {
        if (statusPushConfig) setStatusDraft(normalizeStatusConfig(statusPushConfig));
    }, [statusPushConfig]);
    useEffect(() => {
        if (callConfig) setCallDraft({enabled: Boolean(callConfig.enabled), channelIds: callConfig.channelIds || []});
    }, [callConfig]);

    const deviceOptions = useMemo(() => devices.map((device) => ({id: device.id, label: device.name || device.id.toUpperCase()})), [devices]);
    const channelOptions = useMemo(() => draft.map((channel, index) => withClientDefaults(channel, index)), [draft]);

    const saveMutation = useMutation({
        mutationFn: async () => {
            await Promise.all([
                saveNotificationChannels(normalizeForSave(draft)),
                saveStatusPushConfig(normalizeStatusConfig(statusDraft)),
                saveCallNotificationConfig({enabled: Boolean(callDraft.enabled), channelIds: Array.from(new Set(callDraft.channelIds || []))}),
            ]);
        },
        onSuccess: async () => {
            toast.success('配置已保存');
            await Promise.all([
                queryClient.invalidateQueries({queryKey: ['notificationChannels']}),
                queryClient.invalidateQueries({queryKey: ['statusPushConfig']}),
                queryClient.invalidateQueries({queryKey: ['callNotificationConfig']}),
            ]);
        },
        onError: (error) => toast.error(`保存失败: ${(error as Error).message}`),
    });

    const testChannelMutation = useMutation({
        mutationFn: testNotificationChannel,
        onSuccess: () => toast.success('测试通知已发送'),
        onError: (error) => toast.error(`测试失败: ${(error as Error).message}`),
    });

    const testStatusPushMutation = useMutation({
        mutationFn: testStatusPush,
        onSuccess: () => toast.success('设备状态测试推送已发送'),
        onError: (error) => toast.error(`测试失败: ${(error as Error).message}`),
    });

    const updateChannel = (index: number, patch: Partial<NotificationChannel>) => {
        setDraft((current) => current.map((channel, i) => i === index ? {...channel, ...patch} : channel));
    };

    const updateConfig = (index: number, key: string, value: any) => {
        setDraft((current) => current.map((channel, i) => i === index ? {...channel, config: {...(channel.config || {}), [key]: value}} : channel));
    };

    const toggleDevice = (index: number, deviceId: string) => {
        setDraft((current) => current.map((channel, i) => {
            if (i !== index) return channel;
            const ids = channel.deviceIds || [];
            return {...channel, deviceIds: ids.includes(deviceId) ? ids.filter((id) => id !== deviceId) : [...ids, deviceId]};
        }));
    };

    const toggleChannelId = (ids: string[] | undefined, channelId: string) => {
        const current = ids || [];
        return current.includes(channelId) ? current.filter((id) => id !== channelId) : [...current, channelId];
    };

    const addChannel = () => setDraft((current) => [...current, makeChannel(newType)]);
    const removeChannel = (index: number) => setDraft((current) => current.filter((_, i) => i !== index));
    const save = () => saveMutation.mutate();
    const testChannel = (channel: NotificationChannel) => {
        const normalized = withClientDefaults(channel, 0);
        testChannelMutation.mutate({id: normalized.id, type: normalized.type});
    };

    const renderDeviceScope = (channel: NotificationChannel, index: number) => {
        const selected = channel.deviceIds || [];
        return (
            <div>
                <div className="mb-2 flex items-center justify-between">
                    <label className="text-xs font-semibold text-gray-600">适用 SIM</label>
                    <Button type="button" variant="outline" size="sm" onClick={() => updateChannel(index, {deviceIds: []})}>全部</Button>
                </div>
                <div className="flex flex-wrap gap-2">
                    {deviceOptions.map((device) => {
                        const checked = selected.includes(device.id);
                        return (
                            <label key={device.id} className={`flex cursor-pointer items-center gap-2 rounded-md border px-3 py-1.5 text-sm ${checked ? 'border-blue-200 bg-blue-50 text-blue-700' : 'border-gray-200 bg-white text-gray-600'}`}>
                                <input type="checkbox" className="h-4 w-4" checked={checked} onChange={() => toggleDevice(index, device.id)}/>
                                <span>{device.label}</span>
                            </label>
                        );
                    })}
                </div>
            </div>
        );
    };

    const renderChannelPicker = (selectedIds: string[] | undefined, onChange: (ids: string[]) => void) => (
        <div className="flex flex-wrap gap-2">
            {channelOptions.map((channel) => {
                const id = channel.id || channel.type;
                const checked = (selectedIds || []).includes(id);
                return (
                    <label key={id} className={`flex cursor-pointer items-center gap-2 rounded-md border px-3 py-1.5 text-sm ${checked ? 'border-blue-200 bg-blue-50 text-blue-700' : 'border-gray-200 bg-white text-gray-600'}`}>
                        <input type="checkbox" className="h-4 w-4" checked={checked} onChange={() => onChange(toggleChannelId(selectedIds, id))}/>
                        <span>{channel.name || channelLabel(channel.type)}</span>
                    </label>
                );
            })}
        </div>
    );

    const renderConfig = (channel: NotificationChannel, index: number) => {
        const cfg = channel.config || {};
        if (channel.type === 'dingtalk' || channel.type === 'feishu' || channel.type === 'wecom') {
            return (
                <div className="grid gap-4 md:grid-cols-2">
                    <InputField label="访问令牌" value={cfg.secretKey} onChange={(value) => updateConfig(index, 'secretKey', value)} type="password"/>
                    {channel.type !== 'wecom' && <InputField label="加签密钥" value={cfg.signSecret} onChange={(value) => updateConfig(index, 'signSecret', value)} type="password"/>}
                </div>
            );
        }
        if (channel.type === 'webhook') {
            return (
                <div className="space-y-4">
                    <div className="grid gap-4 md:grid-cols-[1fr_160px]">
                        <InputField label="URL" value={cfg.url} onChange={(value) => updateConfig(index, 'url', value)}/>
                        <div>
                            <label className="mb-2 block text-xs font-semibold text-gray-600">方法</label>
                            <select value={String(cfg.method || 'POST')} onChange={(e) => updateConfig(index, 'method', e.target.value)} className="h-10 w-full rounded-md border border-gray-200 bg-white px-3 text-sm">
                                {['POST', 'PUT', 'PATCH', 'GET', 'DELETE'].map((method) => <option key={method} value={method}>{method}</option>)}
                            </select>
                        </div>
                    </div>
                    <InputField label="Content-Type" value={cfg.contentType || 'application/json; charset=utf-8'} onChange={(value) => updateConfig(index, 'contentType', value)}/>
                    <div>
                        <label className="mb-2 block text-xs font-semibold text-gray-600">请求体模板</label>
                        <Textarea value={String(cfg.body || DEFAULT_WEBHOOK_BODY)} onChange={(e) => updateConfig(index, 'body', e.target.value)} className="min-h-28 font-mono"/>
                    </div>
                </div>
            );
        }
        if (channel.type === 'email') {
            return (
                <div className="grid gap-4 md:grid-cols-2">
                    <InputField label="SMTP 主机" value={cfg.smtpHost} onChange={(value) => updateConfig(index, 'smtpHost', value)}/>
                    <InputField label="SMTP 端口" value={cfg.smtpPort} onChange={(value) => updateConfig(index, 'smtpPort', value)}/>
                    <InputField label="用户名" value={cfg.username} onChange={(value) => updateConfig(index, 'username', value)}/>
                    <InputField label="密码" value={cfg.password} onChange={(value) => updateConfig(index, 'password', value)} type="password"/>
                    <InputField label="发件人" value={cfg.from} onChange={(value) => updateConfig(index, 'from', value)}/>
                    <InputField label="收件人" value={cfg.to} onChange={(value) => updateConfig(index, 'to', value)}/>
                    <div className="md:col-span-2">
                        <InputField label="主题模板" value={cfg.subject} onChange={(value) => updateConfig(index, 'subject', value)}/>
                    </div>
                </div>
            );
        }
        return (
            <div className="grid gap-4 md:grid-cols-2">
                <InputField label="API Token" value={cfg.apiToken} onChange={(value) => updateConfig(index, 'apiToken', value)} type="password"/>
                <InputField label="用户 ID" value={cfg.userid} onChange={(value) => updateConfig(index, 'userid', value)}/>
                <label className="flex items-center gap-2 text-sm text-gray-600">
                    <input type="checkbox" checked={Boolean(cfg.proxyEnabled)} onChange={(e) => updateConfig(index, 'proxyEnabled', e.target.checked)}/>
                    启用 HTTP 代理
                </label>
                <InputField label="代理地址" value={cfg.proxyUrl} onChange={(value) => updateConfig(index, 'proxyUrl', value)}/>
                <InputField label="代理用户名" value={cfg.proxyUsername} onChange={(value) => updateConfig(index, 'proxyUsername', value)}/>
                <InputField label="代理密码" value={cfg.proxyPassword} onChange={(value) => updateConfig(index, 'proxyPassword', value)} type="password"/>
            </div>
        );
    };

    if (isLoading) {
        return <div className="flex items-center justify-center py-20"><div className="h-12 w-12 animate-spin rounded-full border-b-2 border-blue-600"/></div>;
    }

    return (
        <div className="space-y-6">
            <div className="border-b border-gray-200 pb-5">
                <h1 className="text-2xl font-bold text-gray-900">通知渠道</h1>
                <p className="mt-2 text-sm text-gray-500">每个渠道独立绑定 SIM，短信、状态推送和来电通知都会按渠道规则发送。</p>
            </div>

            <Card>
                <CardHeader>
                    <div className="flex flex-wrap items-start justify-between gap-3">
                        <div className="flex items-start gap-3">
                            <div className="flex h-10 w-10 items-center justify-center rounded-md bg-blue-50 text-blue-600"><Radio className="h-5 w-5"/></div>
                            <div>
                                <CardTitle className="text-base">设备状态定时推送</CardTitle>
                                <CardDescription>按设置时间通过通知渠道发送设备在线、SIM、网络和信号状态。</CardDescription>
                            </div>
                        </div>
                        <Button type="button" variant="outline" disabled={testStatusPushMutation.isPending} onClick={() => testStatusPushMutation.mutate()}>
                            {testStatusPushMutation.isPending ? <Loader2 className="mr-2 h-4 w-4 animate-spin"/> : <TestTube className="mr-2 h-4 w-4"/>}
                            测试推送
                        </Button>
                    </div>
                </CardHeader>
                <CardContent className="space-y-4">
                    <label className="flex items-center gap-2 text-sm text-gray-700">
                        <input type="checkbox" checked={statusDraft.enabled} onChange={(e) => setStatusDraft({...statusDraft, enabled: e.target.checked})}/>
                        启用定时推送
                    </label>
                    <div>
                        <label className="mb-2 block text-xs font-semibold text-gray-600">推送时间</label>
                        <div className="flex flex-wrap gap-2">
                            {statusDraft.times.map((time, index) => (
                                <Input key={`${time}-${index}`} type="time" value={time} onChange={(e) => {
                                    const next = [...statusDraft.times];
                                    next[index] = e.target.value;
                                    setStatusDraft({...statusDraft, times: next});
                                }} className="w-32"/>
                            ))}
                            <Button type="button" variant="outline" onClick={() => setStatusDraft({...statusDraft, times: [...statusDraft.times, '09:00']})}>
                                <Plus className="mr-2 h-4 w-4"/>增加
                            </Button>
                            {statusDraft.times.length > 1 && (
                                <Button type="button" variant="outline" onClick={() => setStatusDraft({...statusDraft, times: statusDraft.times.slice(0, -1)})}>删除末项</Button>
                            )}
                        </div>
                    </div>
                    <div>
                        <label className="mb-2 block text-xs font-semibold text-gray-600">推送渠道</label>
                        {renderChannelPicker(statusDraft.channelIds, (ids) => setStatusDraft({...statusDraft, channelIds: ids}))}
                    </div>
                    <div className="flex flex-wrap gap-4 text-sm text-gray-700">
                        <label className="flex items-center gap-2"><input type="checkbox" checked={statusDraft.includeSignal} onChange={(e) => setStatusDraft({...statusDraft, includeSignal: e.target.checked})}/>信号状态</label>
                        <label className="flex items-center gap-2"><input type="checkbox" checked={statusDraft.includeNetwork} onChange={(e) => setStatusDraft({...statusDraft, includeNetwork: e.target.checked})}/>网络状态</label>
                        <label className="flex items-center gap-2"><input type="checkbox" checked={statusDraft.includeSim} onChange={(e) => setStatusDraft({...statusDraft, includeSim: e.target.checked})}/>SIM 状态</label>
                        <label className="flex items-center gap-2"><input type="checkbox" checked={statusDraft.includeRuntime} onChange={(e) => setStatusDraft({...statusDraft, includeRuntime: e.target.checked})}/>运行时长</label>
                    </div>
                </CardContent>
            </Card>

            <Card>
                <CardHeader>
                    <div className="flex items-start gap-3">
                        <div className="flex h-10 w-10 items-center justify-center rounded-md bg-amber-50 text-amber-600"><PhoneCall className="h-5 w-5"/></div>
                        <div>
                            <CardTitle className="text-base">来电挂断通知</CardTitle>
                            <CardDescription>模块检测到来电时不响应，电话挂断后按开关推送通知。</CardDescription>
                        </div>
                    </div>
                </CardHeader>
                <CardContent className="space-y-4">
                    <label className="flex items-center gap-2 text-sm text-gray-700">
                        <input type="checkbox" checked={callDraft.enabled} onChange={(e) => setCallDraft({...callDraft, enabled: e.target.checked})}/>
                        启用来电挂断通知
                    </label>
                    <div>
                        <label className="mb-2 block text-xs font-semibold text-gray-600">推送渠道</label>
                        {renderChannelPicker(callDraft.channelIds, (ids) => setCallDraft({...callDraft, channelIds: ids}))}
                    </div>
                </CardContent>
            </Card>

            <div className="flex flex-wrap items-center gap-3">
                <select value={newType} onChange={(e) => setNewType(e.target.value as ChannelType)} className="h-10 rounded-md border border-gray-200 bg-white px-3 text-sm">
                    {CHANNEL_TYPES.map((item) => <option key={item.type} value={item.type}>{item.label}</option>)}
                </select>
                <Button type="button" onClick={addChannel}>
                    <Plus className="mr-2 h-4 w-4"/>新增渠道
                </Button>
            </div>

            <div className="grid gap-5">
                {draft.length === 0 && <div className="rounded-md border border-dashed border-gray-300 p-8 text-center text-sm text-gray-500">还没有通知渠道</div>}
                {draft.map((channel, index) => {
                    const meta = CHANNEL_TYPES.find((item) => item.type === channel.type);
                    const selected = channel.deviceIds || [];
                    return (
                        <Card key={channel.id || `${channel.type}-${index}`} className="border-gray-200">
                            <CardHeader className="border-b border-gray-100">
                                <div className="flex flex-wrap items-start justify-between gap-3">
                                    <div className="flex items-start gap-3">
                                        <div className={`flex h-11 w-11 items-center justify-center rounded-md ${channel.enabled ? 'bg-blue-50 text-blue-600' : 'bg-gray-100 text-gray-400'}`}>
                                            <Bell className="h-5 w-5"/>
                                        </div>
                                        <div>
                                            <CardTitle className="text-base">{channel.name || meta?.label || channel.type}</CardTitle>
                                            <CardDescription className="mt-1">{meta?.description} · {selected.length === 0 ? '全部 SIM' : selected.join(', ')}</CardDescription>
                                        </div>
                                    </div>
                                    <div className="flex items-center gap-2">
                                        <Button type="button" variant="outline" size="sm" disabled={testChannelMutation.isPending || !channel.enabled} onClick={() => testChannel(channel)}>
                                            <TestTube className="mr-2 h-4 w-4"/>测试
                                        </Button>
                                        <label className="flex items-center gap-2 rounded-md border border-gray-200 px-3 py-2 text-sm">
                                            <input type="checkbox" checked={channel.enabled} onChange={(e) => updateChannel(index, {enabled: e.target.checked})}/>
                                            启用
                                        </label>
                                        <Button type="button" variant="outline" size="sm" onClick={() => removeChannel(index)}>
                                            <Trash2 className="h-4 w-4"/>
                                        </Button>
                                    </div>
                                </div>
                            </CardHeader>
                            <CardContent className="space-y-4 pt-5">
                                <div className="grid gap-4 md:grid-cols-[220px_1fr]">
                                    <InputField label="渠道名称" value={channel.name} onChange={(value) => updateChannel(index, {name: value})}/>
                                    {renderDeviceScope(channel, index)}
                                </div>
                                {renderConfig(channel, index)}
                            </CardContent>
                        </Card>
                    );
                })}
            </div>

            <div className="flex border-t border-gray-200 pt-5">
                <Button onClick={save} disabled={saveMutation.isPending} className="min-w-36">
                    {saveMutation.isPending ? <Loader2 className="mr-2 h-4 w-4 animate-spin"/> : <Save className="mr-2 h-4 w-4"/>}
                    保存配置
                </Button>
            </div>
        </div>
    );
}

function InputField({label, value, onChange, type = 'text'}: {
    label: string;
    value: any;
    onChange: (value: string) => void;
    type?: string;
}) {
    return (
        <div>
            <label className="mb-2 block text-xs font-semibold text-gray-600">{label}</label>
            <Input type={type} autoComplete={type === 'password' ? 'new-password' : undefined} value={String(value || '')} onChange={(e) => onChange(e.target.value)} className="font-mono"/>
        </div>
    );
}
