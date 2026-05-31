import {useEffect, useMemo, useState} from 'react';
import {Bell, Loader2, Plus, Save, TestTube, Trash2} from 'lucide-react';
import {useMutation, useQuery, useQueryClient} from '@tanstack/react-query';
import {toast} from 'sonner';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Textarea} from '@/components/ui/textarea';
import {Card, CardContent, CardDescription, CardHeader, CardTitle} from '@/components/ui/card';
import {getDevices} from '@/api/serial.ts';
import {
    getNotificationChannels,
    type NotificationChannel,
    saveNotificationChannels,
    testNotificationChannel,
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
            return {smtpHost: '', smtpPort: '587', username: '', password: '', from: '', to: '', subject: '收到新短信 - {{from}}'};
        case 'telegram':
            return {apiToken: '', userid: '', proxyEnabled: false, proxyUrl: '', proxyUsername: '', proxyPassword: ''};
        default:
            return {secretKey: '', signSecret: ''};
    }
}

function makeChannel(type: ChannelType): NotificationChannel {
    const suffix = Date.now().toString(36);
    return {
        id: `${type}-${suffix}`,
        name: channelLabel(type),
        type,
        enabled: true,
        deviceIds: [],
        config: defaultConfig(type),
    };
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
        if (typeof value === 'boolean') return value;
        if (value && typeof value === 'object') return Object.keys(value).length > 0;
        return value !== undefined && value !== null;
    });
}

function requiredMissing(channel: NotificationChannel) {
    const cfg = channel.config || {};
    switch (channel.type) {
        case 'dingtalk':
        case 'feishu':
        case 'wecom':
            return !String(cfg.secretKey || '').trim();
        case 'webhook':
            return !String(cfg.url || '').trim() || !String(cfg.body || '').trim();
        case 'email':
            return !String(cfg.smtpHost || '').trim() || !String(cfg.to || '').trim();
        case 'telegram':
            return !String(cfg.apiToken || '').trim() || !String(cfg.userid || '').trim();
        default:
            return false;
    }
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

export default function NotificationChannels() {
    const queryClient = useQueryClient();
    const [draft, setDraft] = useState<NotificationChannel[]>([]);
    const [newType, setNewType] = useState<ChannelType>('dingtalk');

    const {data: channels = [], isLoading} = useQuery({
        queryKey: ['notificationChannels'],
        queryFn: getNotificationChannels,
    });

    const {data: devices = []} = useQuery({
        queryKey: ['serialDevicesForNotifications'],
        queryFn: getDevices,
        refetchInterval: 10000,
    });

    useEffect(() => {
        setDraft(channels.map(withClientDefaults));
    }, [channels]);

    const saveMutation = useMutation({
        mutationFn: saveNotificationChannels,
        onSuccess: () => {
            toast.success('保存成功');
            queryClient.invalidateQueries({queryKey: ['notificationChannels']});
        },
        onError: (error: unknown) => {
            console.error('保存失败:', error);
            toast.error('保存失败');
        },
    });

    const testMutation = useMutation({
        mutationFn: testNotificationChannel,
        onSuccess: () => toast.success('测试通知已发送'),
        onError: (error: unknown) => {
            console.error('测试失败:', error);
            toast.error('测试失败，请检查该渠道配置');
        },
    });

    const deviceOptions = useMemo(() => devices.map((device) => ({
        id: device.id,
        label: device.name || device.id.toUpperCase(),
    })), [devices]);

    const updateChannel = (index: number, patch: Partial<NotificationChannel>) => {
        setDraft((prev) => prev.map((channel, i) => i === index ? {...channel, ...patch} : channel));
    };

    const updateConfig = (index: number, key: string, value: any) => {
        setDraft((prev) => prev.map((channel, i) => {
            if (i !== index) return channel;
            return {...channel, config: {...(channel.config || {}), [key]: value}};
        }));
    };

    const removeChannel = (index: number) => {
        setDraft((prev) => prev.filter((_, i) => i !== index));
    };

    const addChannel = () => {
        setDraft((prev) => [...prev, makeChannel(newType)]);
    };

    const toggleDevice = (index: number, deviceId: string) => {
        setDraft((prev) => prev.map((channel, i) => {
            if (i !== index) return channel;
            const current = channel.deviceIds || [];
            const effective = current.length === 0 ? deviceOptions.map((device) => device.id) : current;
            const next = effective.includes(deviceId)
                ? effective.filter((id) => id !== deviceId)
                : Array.from(new Set([...effective, deviceId]));
            return {...channel, deviceIds: next};
        }));
    };

    const testChannel = (channel: NotificationChannel) => {
        const normalized = withClientDefaults(channel, 0);
        if (requiredMissing(normalized)) {
            toast.error(`${channelLabel(normalized.type)} 缺少必填配置`);
            return;
        }
        testMutation.mutate({id: normalized.id, type: normalized.type});
    };

    const save = () => {
        const next = normalizeForSave(draft);
        const invalid = next.find((channel) => channel.enabled && requiredMissing(channel));
        if (invalid) {
            toast.error(`${invalid.name || channelLabel(invalid.type)} 缺少必填配置`);
            return;
        }
        saveMutation.mutate(next);
    };

    const renderDeviceScope = (channel: NotificationChannel, index: number) => {
        if (deviceOptions.length === 0) return null;
        const selected = channel.deviceIds || [];
        const allDevices = selected.length === 0;

        return (
            <div className="rounded-md border border-gray-200 bg-gray-50 p-3">
                <div className="mb-2 flex items-center justify-between gap-3">
                    <div>
                        <div className="text-xs font-semibold text-gray-700">适用 SIM 卡</div>
                        <div className="text-xs text-gray-400">不选择表示所有 SIM 都推送到这个渠道</div>
                    </div>
                    <Button type="button" variant="outline" size="sm" className="h-8" onClick={() => updateChannel(index, {deviceIds: []})}>
                        全部
                    </Button>
                </div>
                <div className="flex flex-wrap gap-2">
                    {deviceOptions.map((device) => {
                        const checked = allDevices || selected.includes(device.id);
                        return (
                            <label
                                key={device.id}
                                className={`flex cursor-pointer items-center gap-2 rounded-md border px-3 py-1.5 text-sm ${checked ? 'border-blue-200 bg-blue-50 text-blue-700' : 'border-gray-200 bg-white text-gray-600'}`}
                            >
                                <input
                                    type="checkbox"
                                    className="h-4 w-4"
                                    checked={checked}
                                    onChange={() => toggleDevice(index, device.id)}
                                />
                                <span>{device.label}</span>
                            </label>
                        );
                    })}
                </div>
            </div>
        );
    };

    const renderConfig = (channel: NotificationChannel, index: number) => {
        const cfg = channel.config || {};

        if (channel.type === 'dingtalk' || channel.type === 'feishu' || channel.type === 'wecom') {
            return (
                <div className="grid gap-4 md:grid-cols-2">
                    <div>
                        <label className="mb-2 block text-xs font-semibold text-gray-600">访问令牌</label>
                        <Input
                            type="password"
                            autoComplete="new-password"
                            value={String(cfg.secretKey || '')}
                            onChange={(e) => updateConfig(index, 'secretKey', e.target.value)}
                            placeholder={channel.type === 'dingtalk' ? 'access_token' : 'webhook key'}
                            className="font-mono"
                        />
                    </div>
                    {channel.type !== 'wecom' && (
                        <div>
                            <label className="mb-2 block text-xs font-semibold text-gray-600">加签密钥</label>
                            <Input
                                type="password"
                                autoComplete="new-password"
                                value={String(cfg.signSecret || '')}
                                onChange={(e) => updateConfig(index, 'signSecret', e.target.value)}
                                placeholder="可选"
                                className="font-mono"
                            />
                        </div>
                    )}
                </div>
            );
        }

        if (channel.type === 'webhook') {
            return (
                <div className="space-y-4">
                    <div className="grid gap-4 md:grid-cols-[1fr_160px]">
                        <div>
                            <label className="mb-2 block text-xs font-semibold text-gray-600">URL</label>
                            <Input value={String(cfg.url || '')} onChange={(e) => updateConfig(index, 'url', e.target.value)} className="font-mono"/>
                        </div>
                        <div>
                            <label className="mb-2 block text-xs font-semibold text-gray-600">方法</label>
                            <select
                                value={String(cfg.method || 'POST')}
                                onChange={(e) => updateConfig(index, 'method', e.target.value)}
                                className="h-10 w-full rounded-md border border-gray-200 bg-white px-3 text-sm"
                            >
                                {['POST', 'PUT', 'PATCH', 'GET', 'DELETE'].map((method) => <option key={method} value={method}>{method}</option>)}
                            </select>
                        </div>
                    </div>
                    <div>
                        <label className="mb-2 block text-xs font-semibold text-gray-600">Content-Type</label>
                        <Input value={String(cfg.contentType || 'application/json; charset=utf-8')} onChange={(e) => updateConfig(index, 'contentType', e.target.value)} className="font-mono"/>
                    </div>
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
                    <input
                        type="checkbox"
                        checked={Boolean(cfg.proxyEnabled)}
                        onChange={(e) => updateConfig(index, 'proxyEnabled', e.target.checked)}
                    />
                    启用 HTTP 代理
                </label>
                <InputField label="代理地址" value={cfg.proxyUrl} onChange={(value) => updateConfig(index, 'proxyUrl', value)}/>
                <InputField label="代理用户名" value={cfg.proxyUsername} onChange={(value) => updateConfig(index, 'proxyUsername', value)}/>
                <InputField label="代理密码" value={cfg.proxyPassword} onChange={(value) => updateConfig(index, 'proxyPassword', value)} type="password"/>
            </div>
        );
    };

    if (isLoading) {
        return (
            <div className="flex items-center justify-center py-20">
                <div className="h-12 w-12 animate-spin rounded-full border-b-2 border-blue-600"/>
            </div>
        );
    }

    return (
        <div className="space-y-6">
            <div className="border-b border-gray-200 pb-5">
                <h1 className="text-2xl font-bold text-gray-900">通知渠道管理</h1>
                <p className="mt-3 text-sm text-gray-500">每条渠道独立配置，可以绑定到指定 SIM 卡。</p>
            </div>

            <div className="flex flex-wrap items-center gap-3">
                <select
                    value={newType}
                    onChange={(e) => setNewType(e.target.value as ChannelType)}
                    className="h-10 rounded-md border border-gray-200 bg-white px-3 text-sm"
                >
                    {CHANNEL_TYPES.map((item) => <option key={item.type} value={item.type}>{item.label}</option>)}
                </select>
                <Button type="button" onClick={addChannel}>
                    <Plus className="mr-2 h-4 w-4"/>
                    新增渠道
                </Button>
            </div>

            <div className="grid gap-5">
                {draft.length === 0 && (
                    <div className="rounded-md border border-dashed border-gray-300 p-8 text-center text-sm text-gray-500">
                        还没有通知渠道
                    </div>
                )}

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
                                            <CardDescription className="mt-1">
                                                {meta?.description} · {selected.length === 0 ? '全部 SIM' : selected.join(', ')}
                                            </CardDescription>
                                        </div>
                                    </div>
                                    <div className="flex items-center gap-2">
                                        <Button type="button" variant="outline" size="sm" disabled={testMutation.isPending || !channel.enabled} onClick={() => testChannel(channel)}>
                                            <TestTube className="mr-2 h-4 w-4"/>
                                            测试
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
                                    <div>
                                        <label className="mb-2 block text-xs font-semibold text-gray-600">渠道名称</label>
                                        <Input value={channel.name || ''} onChange={(e) => updateChannel(index, {name: e.target.value})}/>
                                    </div>
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
            <Input
                type={type}
                value={String(value || '')}
                onChange={(e) => onChange(e.target.value)}
                className="font-mono"
            />
        </div>
    );
}
