import { Check } from "lucide-react";
import { statusLabel, statusOrder, type Status } from "./types";
export function StatusPipeline({ status }: { status: Status }) { const active=statusOrder.indexOf(status); return <div className="status-pipeline" aria-label={`Status: ${statusLabel[status]}`}>{statusOrder.map((step,i)=><div className="status-step" key={step}><span className={i<=active?"status-dot status-dot-active":"status-dot"}>{i<active?<Check/>:i+1}</span><span className={i===active?"font-semibold text-foreground":"text-muted-foreground"}>{statusLabel[step]}</span></div>)}</div> }
