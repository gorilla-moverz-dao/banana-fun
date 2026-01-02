import { Check, Loader2, Sparkles } from "lucide-react";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";

export type MintStep = "minting" | "revealing" | "done";

interface MintProgressDialogProps {
	open: boolean;
	currentStep: MintStep;
	mintAmount: number;
	onOpenChange: (open: boolean) => void;
}

const steps: { id: MintStep; label: string; description: string }[] = [
	{ id: "minting", label: "Minting NFTs", description: "Sending transaction to mint your NFTs" },
	{ id: "revealing", label: "Revealing", description: "Revealing your NFT metadata" },
	{ id: "done", label: "Complete", description: "Your NFTs are ready!" },
];

function StepIcon({ step, currentStep }: { step: MintStep; currentStep: MintStep }) {
	const stepIndex = steps.findIndex((s) => s.id === step);
	const currentIndex = steps.findIndex((s) => s.id === currentStep);

	if (stepIndex < currentIndex || currentStep === "done") {
		// Completed step
		return (
			<div className="w-10 h-10 rounded-full bg-green-500 flex items-center justify-center">
				<Check className="w-5 h-5 text-white" />
			</div>
		);
	}

	if (stepIndex === currentIndex) {
		// Current step
		return (
			<div className="w-10 h-10 rounded-full bg-yellow-500 flex items-center justify-center animate-pulse">
				<Loader2 className="w-5 h-5 text-black animate-spin" />
			</div>
		);
	}

	// Future step
	return (
		<div className="w-10 h-10 rounded-full bg-muted/50 flex items-center justify-center">
			<div className="w-3 h-3 rounded-full bg-muted-foreground/30" />
		</div>
	);
}

export function MintProgressDialog({ open, currentStep, mintAmount, onOpenChange }: MintProgressDialogProps) {
	const isDone = currentStep === "done";

	return (
		<Dialog open={open} onOpenChange={isDone ? onOpenChange : () => {}}>
			<DialogContent className="sm:max-w-md" onPointerDownOutside={(e) => !isDone && e.preventDefault()}>
				<DialogHeader>
					<DialogTitle className="flex items-center gap-2 text-xl">
						<Sparkles className="w-5 h-5 text-yellow-400" />
						{isDone ? "Minting Complete!" : `Minting ${mintAmount} NFT${mintAmount > 1 ? "s" : ""}...`}
					</DialogTitle>
				</DialogHeader>

				<div className="py-6">
					<div className="space-y-6">
						{steps.map((step, index) => {
							const stepIndex = steps.findIndex((s) => s.id === step.id);
							const currentIndex = steps.findIndex((s) => s.id === currentStep);
							const isActive = stepIndex === currentIndex;
							const isCompleted = stepIndex < currentIndex || currentStep === "done";

							return (
								<div key={step.id} className="flex items-start gap-4">
									<div className="flex flex-col items-center">
										<StepIcon step={step.id} currentStep={currentStep} />
										{index < steps.length - 1 && (
											<div
												className={`w-0.5 h-8 mt-2 ${
													isCompleted ? "bg-green-500" : "bg-muted/50"
												}`}
											/>
										)}
									</div>
									<div className="flex-1 pt-2">
										<div
											className={`font-medium ${
												isActive
													? "text-yellow-400"
													: isCompleted
														? "text-green-400"
														: "text-muted-foreground"
											}`}
										>
											{step.label}
										</div>
										<div className="text-sm text-muted-foreground">{step.description}</div>
									</div>
								</div>
							);
						})}
					</div>
				</div>

				{isDone && (
					<div className="text-center text-sm text-muted-foreground">
						Click outside or press Escape to close
					</div>
				)}
			</DialogContent>
		</Dialog>
	);
}

