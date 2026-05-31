import {useEffect, useState} from 'react';
import type {ComponentType} from 'react';
import {Bell, Link, Mail, MessageSquare, Save, Send, TestTube} from 'lucide-react';
import {useMutation, useQuery, useQueryClient} from '@tanstack/react-query';
import {toast} from 'sonner';
import {Button} from '@/components/ui/button';
import {Input} from '@/components/ui/input';
import {Card, CardContent, CardDescription, CardHeader, CardTitle} from '@/components/ui/card';
import {Textarea} from '@/components/ui/textarea';
import {getDevices} from '@/api/serial.ts';
import {getNotificationChannels, saveNotificationChannels, testNotificationChannel, type NotificationChannel} from '@/api/property.ts';

type ChannelType = NotificationChannel['type'];

type Field = {
    key: string;
    label: string;
    placeholder?: string;
    type?: 'text' | 'password' | 'textarea' | 'checkbox' | 'select';
    options?: string[];
};

type ChannelMeta = {
    type: ChannelType;
    title: string;
    description: string;
    icon: ComponentType<{size?: number; className?: string}>;
    color: string;
    fields: Field[];
};

const channelMetas: ChannelMeta[] = [
    {type: 'dingtalk', title: '钉钉通知', description: '通过钉钉群机器人推送短信和来电通知', icon: Bell, color: 'blue', fields: [
        {key: 'secretKey', label: '访问令牌 (Access Token)', placeholder: '在钉钉机器人配置中获取的 access_token'},
        {key: 'signSecret', label: '加签密钥（可选）', placeholder: 'SEC 开头的加签密钥', type: 'password'},
    ]},
    {type: 'wecom', title: '企业微信通知', description: '通过企业微信群机器人推送通知', icon: MessageSquare, color: 'green', fields: [
        {key: 'secretKey', label: 'Webhook Key', placeholder: '企业微信群机器人的 Webhook Key'},
    ]},
    {type: 'feishu', title: '飞书通知', description: '通过飞书群机器人推送通知', icon: Send, color: 'purple', fields: [
        {key: 'secretKey', label: 'Webhook Token', placeholder: '飞书群机器人的 Webhook Token'},
        {key: 'signSecret', label: '签名密钥（可选）', placeholder: '飞书机器人签名密钥', type: 'password'},
    ]},
    {type: 'webhook', title: '自定义 Webhook', description: '调用自定义 HTTP 接口推送通知', icon: Link, color: 'orange', fields: [
        {key: 'url', label: 'Webhook URL', placeholder: 'https://example.com/webhook'},
        {key: 'method', label: '请求方法', type: 'select', options: ['POST', 'GET', 'PUT', 'PATCH', 'DELETE']},
        {key: 'contentType', label: 'Content-Type', placeholder: 'application/json; charset=utf-8'},
        {key: 'headersJson', label: 'Headers JSON（可选）', placeholder: '{"Authorization":"Bearer xxx"}', type: 'textarea'},
        {key: 'body', label: '请求体模板', placeholder: '{"from":"{{from}}","content":"{{content}}","device":"{{deviceName}}"}', type: 'textarea'},
    ]},
    {type: 'email', title: '邮件通知', description: '通过 SMTP 发送邮件通知', icon: Mail, color: 'indigo', fields: [
        {key: 'smtpHost', label: 'SMTP 服务器', placeholder: 'smtp.example.com'},
        {key: 'smtpPort', label: 'SMTP 端口', placeholder: '587'},
        {key: 'username', label: '用户名', placeholder: 'your-email@example.com'},
        {key: 'password', label: '密码/授权码', placeholder: 'SMTP 密码或授权码', type: 'password'},
        {key: 'from', label: '发件人地址', placeholder: 'sender@example.com'},
        {key: 'to', label: '收件人地址', placeholder: 'receiver@example.com，多个用逗号分隔'},
        {key: 'subject', label: '邮件主题模板', placeholder: '收到新短信 - {{deviceName}} - {{from}}'},
    ]},
    {type: 'telegram', title: 'Telegram 通知', description: '通过 Telegram Bot 推送通知', icon: Bell, color: 'sky', fields: [
        {key: 'apiToken', label: 'Bot API Token', placeholder: '123456:ABCDEF'},
        {key: 'userid', label: 'Chat ID', placeholder: 'Telegram 用户或群组 ID'},
        {key: 'proxyEnabled', label: '启用 HTTP 代理', type: 'checkbox'},
        {key: 'proxyUrl', label: 'HTTP 代理地址', placeholder: 'http://127.0.0.1:7890'},
        {key: 'proxyUsername', label: '代理用户名（可选）'},
        {key: 'proxyPassword', label: '代理密码（可选）', type: 'password'},
    ]},
];

const channelTypes = channelMetas.map((item) => item.type);

const defaults: Record<ChannelType, Record<string, any>> = {
    dingtalk: {secretKey: '', signSecret: ''},
    wecom: {secretKey: ''},
    feishu: {secretKey: '', signSecret: ''},
    webhook: {url: '', method: 'POST', contentType: 'application/json; charset=utf-8', headersJson: '{}', body: '{"from":"{{from}}","content":"{{content}}","deviceId":"{{deviceId}}","deviceName":"{{deviceName}}","timestamp":"{{timestamp}}"}'},
    email: {smtpHost: '', smtpPort: '587', username: '', password: '', from: '', to: '', subject: '收到新短信 - {{deviceName}} - {{from}}'},
    telegram: {apiToken: '', userid: '', proxyEnabled: false, proxyUrl: '', proxyUsername: '', proxyPassword: ''},
};

const emptyEnabled = () => Object.fromEntries(channelTypes.map((type) => [type, false])) as Record<ChannelType, boolean>;
const cloneDefaults = () => Object.fromEntries(channelTypes.map((type) => [type, {...defaults[type]}])) as Record<ChannelType, Record<string, any>>;

export default function NotificationChannels() {
    const queryClient = useQueryClient();
    const [enabled, setEnabled] = useState<Record<ChannelType, boolean>>(emptyEnabled);
    const [configs, setConfigs] = useState<Record<ChannelType, Record<string, any>>>(cloneDefaults);
    const [deviceScopes, setDeviceScopes] = useState<Partial<Record<ChannelType, string[]>>>({});

    const {data: channels = [], isLoading} = useQuery({queryKey: ['notificationChannels'], queryFn: getNotificationChannels});
    const {data: devices = []} = useQuery({queryKey: ['serialDevicesForNotifications'], queryFn: getDevices, refetchInterval: 10000});

    useEffect(() => {
        const nextEnabled = emptyEnabled();
        const nextConfigs = cloneDefaults();
        const nextScopes: Partial<Record<ChannelType, string[]>> = {};
        channels.forEach((channel) => {
            nextEnabled[channel.type] = channel.enabled;
            nextConfigs[channel.type] = {...nextConfigs[channel.type], ...(channel.config || {})};
            if (channel.type === 'webhook') {
                nextConfigs.webhook.headersJson = JSON.stringify(channel.config?.headers || {}, null, 2);
            }
            nextScopes[channel.type] = channel.deviceIds || [];
        });
        setEnabled(nextEnabled);
        setConfigs(nextConfigs);
        setDeviceScopes(nextScopes);
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
            toast.error('测试失败，请检查配置');
        },
    });

    const setConfig = (type: ChannelType, key: string, value: any) => {
        setConfigs((prev) => ({...prev, [type]: {...prev[type], [key]: value}}));
    };

    const updateDeviceScope = (type: ChannelType, deviceId: string, checked: boolean) => {
        setDeviceScopes((prev) => {
            const current = prev[type] || [];
            const effective = current.length === 0 ? devices.map((device) => device.id) : current;
            return {...prev, [type]: checked ? Array.from(new Set([...effective, deviceId])) : effective.filter((id) => id !== deviceId)};
        });
    };

    const renderDeviceScope = (type: ChannelType) => {
        if (devices.length === 0) return null;
        const selected = deviceScopes[type] || [];
        const allDevices = selected.length === 0;
        return (
            <div className="rounded-lg border border-gray-200 bg-gray-50 p-3">
                <div className="mb-2 flex items-center justify-between gap-3">
                    <div>
                        <div className="text-xs font-semibold uppercase tracking-wide text-gray-600">适用 SIM 卡</div>
                        <div className="text-xs text-gray-400">不选择表示所有 SIM 都推送到这个渠道</div>
                    </div>
                    <Button type="button" variant="outline" size="sm" className="h-7 text-xs" onClick={() => setDeviceScopes((prev) => ({...prev, [type]: []}))}>全部</Button>
                </div>
                <div className="flex flex-wrap gap-2">
                    {devices.map((device) => {
                        const checked = allDevices || selected.includes(device.id);
                        return (
                            <label key={device.id} className={`flex cursor-pointer items-center gap-2 rounded-md border px-2.5 py-1.5 text-xs ${checked ? 'border-blue-200 bg-blue-50 text-blue-700' : 'border-gray-200 bg-white text-gray-600'}`}>
                                <input type="checkbox" className="h-3.5 w-3.5" checked={checked} onChange={(e) => updateDeviceScope(type, device.id, e.target.checked)}/>
                                <span>{device.name || device.id.toUpperCase()}</span>
                            </label>
                        );
                    })}
                </div>
            </div>
        );
    };

    const prepareConfig = (type: ChannelType) => {
        const config = {...configs[type]};
        if (type === 'webhook') {
            try {
                const headers = config.headersJson ? JSON.parse(config.headersJson) : {};
                delete config.headersJson;
                if (Object.keys(headers).length > 0) config.headers = headers;
            } catch {
                toast.error('Webhook Headers JSON 格式错误');
                return null;
            }
        }
        return config;
    };

    const hasMeaningfulConfig = (type: ChannelType, config: Record<string, any>) => {
        switch (type) {
            case 'dingtalk':
            case 'wecom':
            case 'feishu':
                return !!config.secretKey;
            case 'webhook':
                return !!config.url;
            case 'email':
                return !!(config.smtpHost || config.username || config.from || config.to);
            case 'telegram':
                return !!(config.apiToken || config.userid);
        }
    };

    const handleSave = () => {
        const nextChannels: NotificationChannel[] = [];
        for (const type of channelTypes) {
            const config = prepareConfig(type);
            if (!config) return;
            if (enabled[type] || hasMeaningfulConfig(type, config)) {
                nextChannels.push({type, enabled: enabled[type], deviceIds: deviceScopes[type] || [], config});
            }
        }
        saveMutation.mutate(nextChannels);
    };

    if (isLoading) {
        return <div className="flex justify-center items-center py-20"><div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div></div>;
    }

    return (
        <div className="space-y-8 animate-in fade-in duration-300">
            <div className="border-b border-gray-200 pb-5">
                <h1 className="text-2xl font-bold text-gray-900">通知渠道管理</h1>
                <p className="text-sm text-gray-500 mt-3">配置第三方消息推送渠道，并为不同 SIM 卡选择不同推送目标</p>
            </div>

            <div className="grid grid-cols-1 gap-6">
                {channelMetas.map((meta) => {
                    const Icon = meta.icon;
                    return (
                        <Card key={meta.type} className={`border transition-all ${enabled[meta.type] ? 'border-blue-200 bg-blue-50/10' : 'border-gray-200'}`}>
                            <CardHeader className="border-b border-gray-100 bg-white/50">
                                <div className="flex items-center justify-between gap-4">
                                    <div className="flex items-center gap-3">
                                        <div className={`w-12 h-12 rounded-lg flex items-center justify-center ${enabled[meta.type] ? 'bg-blue-50 text-blue-600' : 'bg-gray-100 text-gray-400'}`}>
                                            <Icon size={24}/>
                                        </div>
                                        <div>
                                            <div className="flex items-center gap-2">
                                                <CardTitle className="text-lg font-bold text-gray-800">{meta.title}</CardTitle>
                                                <div className={`w-2 h-2 rounded-full ${enabled[meta.type] ? 'bg-green-500' : 'bg-gray-300'}`}></div>
                                                <span className="text-xs text-gray-500">{enabled[meta.type] ? '已启用' : '未启用'}</span>
                                            </div>
                                            <CardDescription className="mt-1.5 text-xs">{meta.description}</CardDescription>
                                        </div>
                                    </div>
                                    <div className="flex items-center gap-3">
                                        {enabled[meta.type] && (
                                            <Button variant="outline" size="sm" disabled={testMutation.isPending} onClick={() => testMutation.mutate(meta.type)} className="text-xs bg-gray-100 hover:bg-gray-200 border-none">
                                                <TestTube className="w-3.5 h-3.5 mr-1.5"/>
                                                发送测试
                                            </Button>
                                        )}
                                        <label className="relative inline-flex items-center cursor-pointer">
                                            <input type="checkbox" className="sr-only peer" checked={enabled[meta.type]} onChange={(e) => setEnabled((prev) => ({...prev, [meta.type]: e.target.checked}))}/>
                                            <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-2 peer-focus:ring-blue-300 rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-blue-600"></div>
                                        </label>
                                    </div>
                                </div>
                            </CardHeader>

                            {enabled[meta.type] && (
                                <CardContent className="space-y-4 animate-in slide-in-from-top-2 duration-200">
                                    {renderDeviceScope(meta.type)}
                                    {meta.fields.map((field) => (
                                        <div key={field.key}>
                                            <label className="block text-xs font-semibold text-gray-600 mb-2 uppercase tracking-wide">{field.label}</label>
                                            {field.type === 'textarea' ? (
                                                <Textarea value={String(configs[meta.type]?.[field.key] ?? '')} onChange={(e) => setConfig(meta.type, field.key, e.target.value)} placeholder={field.placeholder} className="min-h-[90px] font-mono text-sm"/>
                                            ) : field.type === 'checkbox' ? (
                                                <label className="flex items-center gap-2 text-sm text-gray-600">
                                                    <input type="checkbox" checked={!!configs[meta.type]?.[field.key]} onChange={(e) => setConfig(meta.type, field.key, e.target.checked)}/>
                                                    启用
                                                </label>
                                            ) : field.type === 'select' ? (
                                                <select value={String(configs[meta.type]?.[field.key] ?? '')} onChange={(e) => setConfig(meta.type, field.key, e.target.value)} className="h-10 w-full rounded-md border border-gray-200 bg-gray-50 px-3 text-sm">
                                                    {field.options?.map((option) => <option key={option} value={option}>{option}</option>)}
                                                </select>
                                            ) : (
                                                <Input type={field.type === 'password' ? 'password' : 'text'} value={String(configs[meta.type]?.[field.key] ?? '')} onChange={(e) => setConfig(meta.type, field.key, e.target.value)} placeholder={field.placeholder} className="bg-gray-50 border-gray-200 font-mono text-sm"/>
                                            )}
                                        </div>
                                    ))}
                                </CardContent>
                            )}
                        </Card>
                    );
                })}
            </div>

            <div className="sticky bottom-4 flex justify-end">
                <Button onClick={handleSave} disabled={saveMutation.isPending} className="bg-blue-600 hover:bg-blue-700 shadow-lg px-8">
                    <Save className="w-4 h-4 mr-2"/>
                    {saveMutation.isPending ? '保存中...' : '保存配置'}
                </Button>
            </div>
        </div>
    );
}
