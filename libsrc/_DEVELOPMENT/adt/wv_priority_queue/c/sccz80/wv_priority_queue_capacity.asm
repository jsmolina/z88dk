
; size_t wv_priority_queue_capacity(wv_priority_queue_t *q)

SECTION code_adt_wv_priority_queue

PUBLIC wv_priority_queue_capacity

EXTERN asm_wv_priority_queue_capacity

defc wv_priority_queue_capacity = asm_wv_priority_queue_capacity
