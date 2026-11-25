interface Props {
  checked: boolean;
  onChange: (checked: boolean) => void;
  label: string;
}

/** iOS-style switch; `label` is for screen readers. */
export function Toggle({ checked, onChange, label }: Props) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      aria-label={label}
      className={`toggle ${checked ? "on" : ""}`}
      onClick={(e) => {
        e.stopPropagation();
        onChange(!checked);
      }}
    >
      <span className="knob" />
    </button>
  );
}
