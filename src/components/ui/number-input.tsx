/**
 * NumberInput Component
 * 
 * A customizable number input component with increment/decrement buttons.
 * Built on top of Shadcn UI components for consistent styling.
 * 
 * Features:
 * - Min/max value constraints
 * - Step increment/decrement
 * - Disabled states for buttons when limits are reached
 * - Mobile-friendly touch targets
 * - Accessible with proper ARIA labels
 * 
 * @example
 * ```tsx
 * <NumberInput
 *   value={amount}
 *   onChange={setAmount}
 *   min={1}
 *   max={10}
 *   step={1}
 *   disabled={false}
 * />
 * ```
 * 
 * Note: The value can be undefined when the input is empty.
 * The onChange callback will receive undefined for empty inputs.
 */

import * as React from 'react'
import { Minus, Plus } from 'lucide-react'
import { cn } from '@/lib/utils'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'

export interface NumberInputProps
  extends Omit<React.InputHTMLAttributes<HTMLInputElement>, 'onChange'> {
  value: number | undefined
  onChange: (value: number | undefined) => void
  min?: number
  max?: number
  step?: number
  disabled?: boolean
  className?: string
  inputClassName?: string
  buttonClassName?: string
}

const NumberInput = React.forwardRef<HTMLDivElement, NumberInputProps>(
  (
    {
      value,
      onChange,
      min = 1,
      max,
      step = 1,
      disabled = false,
      className,
      inputClassName,
      buttonClassName,
      ...props
    },
    ref,
  ) => {
    const handleIncrement = () => {
      if (disabled) return
      const currentValue = value ?? min
      const newValue = currentValue + step
      if (max === undefined || newValue <= max) {
        onChange(newValue)
      }
    }

    const handleDecrement = () => {
      if (disabled) return
      const currentValue = value ?? min
      const newValue = currentValue - step
      if (newValue >= min) {
        onChange(newValue)
      }
    }

    const handleInputChange = (e: React.ChangeEvent<HTMLInputElement>) => {
      if (disabled) return
      const inputValue = e.target.value
      
      if (inputValue === '') {
        onChange(undefined)
        return
      }
      
      const numValue = Number(inputValue)
      if (isNaN(numValue)) return
      
      const clampedValue = Math.max(min, Math.min(max || Infinity, numValue))
      onChange(clampedValue)
    }

    const currentValue = value ?? min
    const isDecrementDisabled = disabled || currentValue <= min
    const isIncrementDisabled = disabled || (max !== undefined && currentValue >= max)

    return (
      <div
        ref={ref}
        className={cn(
          'flex items-center rounded-md border border-input bg-secondary/80',
          className,
          disabled && 'opacity-50'
        )}
      >
        <Button
          type="button"
          variant="ghost"
          size="sm"
          onClick={handleDecrement}
          disabled={isDecrementDisabled}
          className={cn(
            'h-auto rounded-r-none border-0 px-3 py-2 hover:bg-muted/50',
            buttonClassName,
          )}
          aria-label="Decrease value"
        >
          <Minus className="h-4 w-4" />
        </Button>
        
        <Input
          type="number"
          value={value ?? ''}
          onChange={handleInputChange}
          min={min}
          max={max}
          step={step}
          disabled={disabled}
          className={cn(
            'border-0 rounded-none text-center focus-visible:ring-0 focus-visible:ring-offset-0 [appearance:textfield] [&::-webkit-outer-spin-button]:appearance-none [&::-webkit-inner-spin-button]:appearance-none',
            inputClassName,
          )}
          {...props}
        />
        
        <Button
          type="button"
          variant="ghost"
          size="sm"
          onClick={handleIncrement}
          disabled={isIncrementDisabled}
          className={cn(
            'h-auto rounded-l-none border-0 px-3 py-2 hover:bg-muted/50',
            buttonClassName,
          )}
          aria-label="Increase value"
        >
          <Plus className="h-4 w-4" />
        </Button>
      </div>
    )
  },
)

NumberInput.displayName = 'NumberInput'

export { NumberInput }
